/**
 * video_probe_android.c
 *
 * Android implementation of video_probe using MediaMetadataRetriever via JNI.
 * This eliminates the need for FFmpeg on Android by using platform APIs.
 */

#include "video_probe.h"
#include <jni.h>
#include <string.h>
#include <android/log.h>

#define LOG_TAG "video_probe"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// Cached JVM reference (set during JNI_OnLoad)
static JavaVM* g_jvm = NULL;

// MediaMetadataRetriever metadata keys
#define METADATA_KEY_DURATION 9
#define METADATA_KEY_VIDEO_FRAME_COUNT 32  // API 28+
#define METADATA_KEY_VIDEO_WIDTH 18
#define METADATA_KEY_VIDEO_HEIGHT 19

// getFrameAtTime options
#define OPTION_CLOSEST_SYNC 0
#define OPTION_CLOSEST 3

/**
 * Called when the native library is loaded via System.loadLibrary.
 * Note: This is NOT called when loaded via FFI, so we also provide nativeInit().
 */
JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* reserved) {
    g_jvm = vm;
    LOGD("video_probe JNI_OnLoad: JavaVM cached");
    return JNI_VERSION_1_6;
}

/**
 * JNI function to initialize JavaVM from Kotlin.
 * This must be called when the library is loaded via FFI since JNI_OnLoad won't be triggered.
 */
JNIEXPORT void JNICALL
Java_com_example_video_1probe_VideoProbePlugin_nativeInit(JNIEnv* env, jclass clazz) {
    if (g_jvm == NULL) {
        (*env)->GetJavaVM(env, &g_jvm);
        LOGD("video_probe nativeInit: JavaVM cached from Kotlin");
    }
}

/**
 * Get JNIEnv for the current thread.
 * Attaches thread to JVM if necessary.
 */
static JNIEnv* get_jni_env(int* should_detach) {
    JNIEnv* env = NULL;
    *should_detach = 0;
    
    if (g_jvm == NULL) {
        LOGE("JavaVM not initialized");
        return NULL;
    }
    
    jint result = (*g_jvm)->GetEnv(g_jvm, (void**)&env, JNI_VERSION_1_6);
    if (result == JNI_EDETACHED) {
        result = (*g_jvm)->AttachCurrentThread(g_jvm, &env, NULL);
        if (result != JNI_OK) {
            LOGE("Failed to attach thread to JVM");
            return NULL;
        }
        *should_detach = 1;
    } else if (result != JNI_OK) {
        LOGE("Failed to get JNIEnv: %d", result);
        return NULL;
    }
    
    return env;
}

/**
 * Detach thread from JVM if necessary.
 */
static void release_jni_env(int should_detach) {
    if (should_detach && g_jvm != NULL) {
        (*g_jvm)->DetachCurrentThread(g_jvm);
    }
}

/**
 * Get Android SDK version.
 */
static int get_sdk_version(JNIEnv* env) {
    jclass buildClass = (*env)->FindClass(env, "android/os/Build$VERSION");
    if (buildClass == NULL) {
        LOGE("Failed to find Build.VERSION class");
        return 0;
    }
    
    jfieldID sdkIntField = (*env)->GetStaticFieldID(env, buildClass, "SDK_INT", "I");
    if (sdkIntField == NULL) {
        (*env)->DeleteLocalRef(env, buildClass);
        LOGE("Failed to find SDK_INT field");
        return 0;
    }
    
    jint sdkVersion = (*env)->GetStaticIntField(env, buildClass, sdkIntField);
    (*env)->DeleteLocalRef(env, buildClass);
    
    return (int)sdkVersion;
}

/**
 * Create a new MediaMetadataRetriever instance and set data source.
 * Returns NULL on error. Caller must delete local ref when done.
 */
static jobject create_retriever(JNIEnv* env, const char* path) {
    // Find MediaMetadataRetriever class
    jclass retrieverClass = (*env)->FindClass(env, "android/media/MediaMetadataRetriever");
    if (retrieverClass == NULL) {
        LOGE("Failed to find MediaMetadataRetriever class");
        return NULL;
    }
    
    // Get constructor
    jmethodID constructor = (*env)->GetMethodID(env, retrieverClass, "<init>", "()V");
    if (constructor == NULL) {
        (*env)->DeleteLocalRef(env, retrieverClass);
        LOGE("Failed to find MediaMetadataRetriever constructor");
        return NULL;
    }
    
    // Create instance
    jobject retriever = (*env)->NewObject(env, retrieverClass, constructor);
    if (retriever == NULL) {
        (*env)->DeleteLocalRef(env, retrieverClass);
        LOGE("Failed to create MediaMetadataRetriever instance");
        return NULL;
    }
    
    // Get setDataSource method
    jmethodID setDataSource = (*env)->GetMethodID(env, retrieverClass, "setDataSource",
                                                   "(Ljava/lang/String;)V");
    if (setDataSource == NULL) {
        (*env)->DeleteLocalRef(env, retriever);
        (*env)->DeleteLocalRef(env, retrieverClass);
        LOGE("Failed to find setDataSource method");
        return NULL;
    }
    
    // Create path string
    jstring jpath = (*env)->NewStringUTF(env, path);
    if (jpath == NULL) {
        (*env)->DeleteLocalRef(env, retriever);
        (*env)->DeleteLocalRef(env, retrieverClass);
        LOGE("Failed to create path string");
        return NULL;
    }
    
    // Set data source
    (*env)->CallVoidMethod(env, retriever, setDataSource, jpath);
    (*env)->DeleteLocalRef(env, jpath);
    
    // Check for exceptions
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
        (*env)->DeleteLocalRef(env, retriever);
        (*env)->DeleteLocalRef(env, retrieverClass);
        LOGE("setDataSource threw an exception for path: %s", path);
        return NULL;
    }
    
    (*env)->DeleteLocalRef(env, retrieverClass);
    return retriever;
}

/**
 * Release MediaMetadataRetriever instance.
 */
static void release_retriever(JNIEnv* env, jobject retriever) {
    if (retriever == NULL) return;
    
    jclass retrieverClass = (*env)->GetObjectClass(env, retriever);
    if (retrieverClass != NULL) {
        jmethodID releaseMethod = (*env)->GetMethodID(env, retrieverClass, "release", "()V");
        if (releaseMethod != NULL) {
            (*env)->CallVoidMethod(env, retriever, releaseMethod);
            if ((*env)->ExceptionCheck(env)) {
                (*env)->ExceptionClear(env);
            }
        }
        (*env)->DeleteLocalRef(env, retrieverClass);
    }
    (*env)->DeleteLocalRef(env, retriever);
}

/**
 * Extract metadata from MediaMetadataRetriever.
 * Returns allocated string that must be freed, or NULL on error.
 */
static char* extract_metadata(JNIEnv* env, jobject retriever, int key) {
    jclass retrieverClass = (*env)->GetObjectClass(env, retriever);
    if (retrieverClass == NULL) return NULL;
    
    jmethodID extractMethod = (*env)->GetMethodID(env, retrieverClass, "extractMetadata",
                                                   "(I)Ljava/lang/String;");
    (*env)->DeleteLocalRef(env, retrieverClass);
    
    if (extractMethod == NULL) {
        LOGE("Failed to find extractMetadata method");
        return NULL;
    }
    
    jstring result = (jstring)(*env)->CallObjectMethod(env, retriever, extractMethod, key);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        return NULL;
    }
    
    if (result == NULL) {
        return NULL;
    }
    
    const char* resultStr = (*env)->GetStringUTFChars(env, result, NULL);
    if (resultStr == NULL) {
        (*env)->DeleteLocalRef(env, result);
        return NULL;
    }
    
    char* copy = strdup(resultStr);
    (*env)->ReleaseStringUTFChars(env, result, resultStr);
    (*env)->DeleteLocalRef(env, result);
    
    return copy;
}

// ============================================================================
// Public API Implementation
// ============================================================================

EXPORT intptr_t sum(intptr_t a, intptr_t b) {
    return a + b;
}

EXPORT double get_duration(char* path) {
    if (path == NULL) return -1.0;
    
    int should_detach = 0;
    JNIEnv* env = get_jni_env(&should_detach);
    if (env == NULL) return -1.0;
    
    jobject retriever = create_retriever(env, path);
    if (retriever == NULL) {
        release_jni_env(should_detach);
        return -1.0;
    }
    
    char* durationStr = extract_metadata(env, retriever, METADATA_KEY_DURATION);
    release_retriever(env, retriever);
    release_jni_env(should_detach);
    
    if (durationStr == NULL) {
        LOGE("Failed to extract duration metadata");
        return -1.0;
    }
    
    // Duration is in milliseconds
    double durationMs = atof(durationStr);
    free(durationStr);
    
    return durationMs / 1000.0;
}

EXPORT int get_frame_count(char* path) {
    if (path == NULL) return -1;
    
    int should_detach = 0;
    JNIEnv* env = get_jni_env(&should_detach);
    if (env == NULL) return -1;
    
    int sdkVersion = get_sdk_version(env);
    
    jobject retriever = create_retriever(env, path);
    if (retriever == NULL) {
        release_jni_env(should_detach);
        return -1;
    }
    
    int frameCount = -1;
    
    // API 28+ has METADATA_KEY_VIDEO_FRAME_COUNT
    if (sdkVersion >= 28) {
        char* frameCountStr = extract_metadata(env, retriever, METADATA_KEY_VIDEO_FRAME_COUNT);
        if (frameCountStr != NULL) {
            frameCount = atoi(frameCountStr);
            free(frameCountStr);
        }
    }
    
    // Fallback: estimate from duration (assuming 30fps if frame count not available)
    if (frameCount <= 0) {
        char* durationStr = extract_metadata(env, retriever, METADATA_KEY_DURATION);
        if (durationStr != NULL) {
            double durationMs = atof(durationStr);
            free(durationStr);
            // Estimate at 30fps
            frameCount = (int)((durationMs / 1000.0) * 30.0);
        }
    }
    
    release_retriever(env, retriever);
    release_jni_env(should_detach);
    
    return frameCount;
}

EXPORT uint8_t* extract_frame(char* path, int frameNum, int* outSize) {
    if (path == NULL || outSize == NULL) return NULL;
    *outSize = 0;
    
    int should_detach = 0;
    JNIEnv* env = get_jni_env(&should_detach);
    if (env == NULL) return NULL;
    
    jobject retriever = create_retriever(env, path);
    if (retriever == NULL) {
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Get duration to calculate time for frame
    char* durationStr = extract_metadata(env, retriever, METADATA_KEY_DURATION);
    if (durationStr == NULL) {
        release_retriever(env, retriever);
        release_jni_env(should_detach);
        return NULL;
    }
    
    double durationMs = atof(durationStr);
    free(durationStr);
    
    // Estimate 30fps for calculating time
    double timeUs = ((double)frameNum / 30.0) * 1000000.0;
    
    // Clamp to duration
    if (timeUs > durationMs * 1000.0) {
        timeUs = durationMs * 1000.0 - 1000.0;
        if (timeUs < 0) timeUs = 0;
    }
    
    // Get retriever class
    jclass retrieverClass = (*env)->GetObjectClass(env, retriever);
    if (retrieverClass == NULL) {
        release_retriever(env, retriever);
        release_jni_env(should_detach);
        return NULL;
    }
    
    // getFrameAtTime(long timeUs, int option)
    jmethodID getFrameMethod = (*env)->GetMethodID(env, retrieverClass, "getFrameAtTime",
                                                    "(JI)Landroid/graphics/Bitmap;");
    (*env)->DeleteLocalRef(env, retrieverClass);
    
    if (getFrameMethod == NULL) {
        LOGE("Failed to find getFrameAtTime method");
        release_retriever(env, retriever);
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Call getFrameAtTime
    jobject bitmap = (*env)->CallObjectMethod(env, retriever, getFrameMethod,
                                               (jlong)timeUs, OPTION_CLOSEST_SYNC);
    release_retriever(env, retriever);
    
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
        release_jni_env(should_detach);
        return NULL;
    }
    
    if (bitmap == NULL) {
        LOGE("getFrameAtTime returned null");
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Create ByteArrayOutputStream
    jclass baosClass = (*env)->FindClass(env, "java/io/ByteArrayOutputStream");
    if (baosClass == NULL) {
        (*env)->DeleteLocalRef(env, bitmap);
        release_jni_env(should_detach);
        return NULL;
    }
    
    jmethodID baosConstructor = (*env)->GetMethodID(env, baosClass, "<init>", "()V");
    jobject baos = (*env)->NewObject(env, baosClass, baosConstructor);
    if (baos == NULL) {
        (*env)->DeleteLocalRef(env, baosClass);
        (*env)->DeleteLocalRef(env, bitmap);
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Get Bitmap.CompressFormat.JPEG
    jclass formatClass = (*env)->FindClass(env, "android/graphics/Bitmap$CompressFormat");
    if (formatClass == NULL) {
        (*env)->DeleteLocalRef(env, baos);
        (*env)->DeleteLocalRef(env, baosClass);
        (*env)->DeleteLocalRef(env, bitmap);
        release_jni_env(should_detach);
        return NULL;
    }
    
    jfieldID jpegField = (*env)->GetStaticFieldID(env, formatClass, "JPEG",
                                                   "Landroid/graphics/Bitmap$CompressFormat;");
    if (jpegField == NULL) {
        (*env)->DeleteLocalRef(env, formatClass);
        (*env)->DeleteLocalRef(env, baos);
        (*env)->DeleteLocalRef(env, baosClass);
        (*env)->DeleteLocalRef(env, bitmap);
        release_jni_env(should_detach);
        return NULL;
    }
    
    jobject jpegFormat = (*env)->GetStaticObjectField(env, formatClass, jpegField);
    (*env)->DeleteLocalRef(env, formatClass);
    
    if (jpegFormat == NULL) {
        (*env)->DeleteLocalRef(env, baos);
        (*env)->DeleteLocalRef(env, baosClass);
        (*env)->DeleteLocalRef(env, bitmap);
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Bitmap.compress(format, quality, outputStream)
    jclass bitmapClass = (*env)->GetObjectClass(env, bitmap);
    jmethodID compressMethod = (*env)->GetMethodID(env, bitmapClass, "compress",
                                                    "(Landroid/graphics/Bitmap$CompressFormat;ILjava/io/OutputStream;)Z");
    (*env)->DeleteLocalRef(env, bitmapClass);
    
    if (compressMethod == NULL) {
        (*env)->DeleteLocalRef(env, jpegFormat);
        (*env)->DeleteLocalRef(env, baos);
        (*env)->DeleteLocalRef(env, baosClass);
        (*env)->DeleteLocalRef(env, bitmap);
        release_jni_env(should_detach);
        return NULL;
    }
    
    jboolean compressed = (*env)->CallBooleanMethod(env, bitmap, compressMethod,
                                                     jpegFormat, 90, baos);
    (*env)->DeleteLocalRef(env, jpegFormat);
    (*env)->DeleteLocalRef(env, bitmap);
    
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        (*env)->DeleteLocalRef(env, baos);
        (*env)->DeleteLocalRef(env, baosClass);
        release_jni_env(should_detach);
        return NULL;
    }
    
    if (!compressed) {
        LOGE("Bitmap.compress failed");
        (*env)->DeleteLocalRef(env, baos);
        (*env)->DeleteLocalRef(env, baosClass);
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Get byte array from ByteArrayOutputStream
    jmethodID toByteArrayMethod = (*env)->GetMethodID(env, baosClass, "toByteArray", "()[B");
    (*env)->DeleteLocalRef(env, baosClass);
    
    if (toByteArrayMethod == NULL) {
        (*env)->DeleteLocalRef(env, baos);
        release_jni_env(should_detach);
        return NULL;
    }
    
    jbyteArray byteArray = (jbyteArray)(*env)->CallObjectMethod(env, baos, toByteArrayMethod);
    (*env)->DeleteLocalRef(env, baos);
    
    if (byteArray == NULL) {
        release_jni_env(should_detach);
        return NULL;
    }
    
    // Copy to C buffer
    jsize length = (*env)->GetArrayLength(env, byteArray);
    uint8_t* buffer = (uint8_t*)malloc(length);
    if (buffer == NULL) {
        (*env)->DeleteLocalRef(env, byteArray);
        release_jni_env(should_detach);
        return NULL;
    }
    
    (*env)->GetByteArrayRegion(env, byteArray, 0, length, (jbyte*)buffer);
    (*env)->DeleteLocalRef(env, byteArray);
    release_jni_env(should_detach);
    
    *outSize = (int)length;
    LOGD("Extracted frame %d: %d bytes", frameNum, *outSize);
    
    return buffer;
}

EXPORT void free_frame(uint8_t* buffer) {
    if (buffer != NULL) {
        free(buffer);
    }
}
