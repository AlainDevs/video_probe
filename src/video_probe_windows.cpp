/**
 * Windows-specific video probe implementation using Media Foundation.
 *
 * This file provides video metadata extraction and frame extraction
 * using Windows Media Foundation APIs.
 */

#ifdef _WIN32

#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <propvarutil.h>
#include <shlwapi.h>
#include <wincodec.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "windowscodecs.lib")

// Export macro for DLL
#define EXPORT __declspec(dllexport)

// Forward declarations
extern "C" {
    EXPORT double get_duration(const char* path);
    EXPORT int get_frame_count(const char* path);
    EXPORT unsigned char* extract_frame(const char* path, int frame_num, int* out_size);
    EXPORT void free_frame(unsigned char* data);
}

// Helper class for COM initialization
class ComInitializer {
public:
    ComInitializer() : initialized_(false) {
        HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
        if (SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE) {
            initialized_ = true;
        }
    }
    ~ComInitializer() {
        if (initialized_) {
            CoUninitialize();
        }
    }
    bool IsInitialized() const { return initialized_; }
private:
    bool initialized_;
};

// Helper class for Media Foundation initialization
class MFInitializer {
public:
    MFInitializer() : initialized_(false) {
        HRESULT hr = MFStartup(MF_VERSION);
        if (SUCCEEDED(hr)) {
            initialized_ = true;
        }
    }
    ~MFInitializer() {
        if (initialized_) {
            MFShutdown();
        }
    }
    bool IsInitialized() const { return initialized_; }
private:
    bool initialized_;
};

// Helper to convert UTF-8 path to wide string
static wchar_t* Utf8ToWide(const char* utf8) {
    if (utf8 == NULL) return NULL;
    
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    if (len == 0) return NULL;
    
    wchar_t* wide = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wide == NULL) return NULL;
    
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wide, len);
    return wide;
}

// Get video duration in seconds
extern "C" double get_duration(const char* path) {
    if (path == NULL || strlen(path) == 0) {
        return -1.0;
    }

    ComInitializer comInit;
    if (!comInit.IsInitialized()) {
        return -1.0;
    }

    MFInitializer mfInit;
    if (!mfInit.IsInitialized()) {
        return -1.0;
    }

    wchar_t* widePath = Utf8ToWide(path);
    if (widePath == NULL) {
        return -1.0;
    }

    IMFSourceReader* reader = NULL;
    HRESULT hr = MFCreateSourceReaderFromURL(widePath, NULL, &reader);
    free(widePath);

    if (FAILED(hr) || reader == NULL) {
        return -1.0;
    }

    PROPVARIANT var;
    PropVariantInit(&var);
    
    hr = reader->GetPresentationAttribute(
        (DWORD)MF_SOURCE_READER_MEDIASOURCE,
        MF_PD_DURATION,
        &var
    );

    double duration = -1.0;
    if (SUCCEEDED(hr) && var.vt == VT_UI8) {
        // Duration is in 100-nanosecond units
        duration = (double)var.uhVal.QuadPart / 10000000.0;
    }

    PropVariantClear(&var);
    reader->Release();

    return duration;
}

// Get frame count by calculating duration * fps
extern "C" int get_frame_count(const char* path) {
    if (path == NULL || strlen(path) == 0) {
        return -1;
    }

    ComInitializer comInit;
    if (!comInit.IsInitialized()) {
        return -1;
    }

    MFInitializer mfInit;
    if (!mfInit.IsInitialized()) {
        return -1;
    }

    wchar_t* widePath = Utf8ToWide(path);
    if (widePath == NULL) {
        return -1;
    }

    IMFSourceReader* reader = NULL;
    HRESULT hr = MFCreateSourceReaderFromURL(widePath, NULL, &reader);
    free(widePath);

    if (FAILED(hr) || reader == NULL) {
        return -1;
    }

    // Get duration
    PROPVARIANT var;
    PropVariantInit(&var);
    
    hr = reader->GetPresentationAttribute(
        (DWORD)MF_SOURCE_READER_MEDIASOURCE,
        MF_PD_DURATION,
        &var
    );

    if (FAILED(hr) || var.vt != VT_UI8) {
        PropVariantClear(&var);
        reader->Release();
        return -1;
    }

    double duration = (double)var.uhVal.QuadPart / 10000000.0;
    PropVariantClear(&var);

    // Get video media type to find frame rate
    IMFMediaType* mediaType = NULL;
    hr = reader->GetNativeMediaType(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        0,
        &mediaType
    );

    if (FAILED(hr) || mediaType == NULL) {
        reader->Release();
        return -1;
    }

    // Get frame rate
    UINT32 numerator = 0, denominator = 0;
    hr = MFGetAttributeRatio(mediaType, MF_MT_FRAME_RATE, &numerator, &denominator);
    
    double fps = 30.0; // Default fallback
    if (SUCCEEDED(hr) && denominator > 0) {
        fps = (double)numerator / (double)denominator;
    }

    mediaType->Release();
    reader->Release();

    int frameCount = (int)(duration * fps + 0.5);
    return frameCount > 0 ? frameCount : -1;
}

// Extract a frame at the given frame number and return as JPEG
extern "C" unsigned char* extract_frame(const char* path, int frame_num, int* out_size) {
    if (path == NULL || strlen(path) == 0 || frame_num < 0 || out_size == NULL) {
        if (out_size) *out_size = 0;
        return NULL;
    }

    *out_size = 0;

    ComInitializer comInit;
    if (!comInit.IsInitialized()) {
        return NULL;
    }

    MFInitializer mfInit;
    if (!mfInit.IsInitialized()) {
        return NULL;
    }

    wchar_t* widePath = Utf8ToWide(path);
    if (widePath == NULL) {
        return NULL;
    }

    IMFSourceReader* reader = NULL;
    HRESULT hr = MFCreateSourceReaderFromURL(widePath, NULL, &reader);
    free(widePath);

    if (FAILED(hr) || reader == NULL) {
        return NULL;
    }

    // Get video media type to find frame rate
    IMFMediaType* nativeType = NULL;
    hr = reader->GetNativeMediaType(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        0,
        &nativeType
    );

    if (FAILED(hr) || nativeType == NULL) {
        reader->Release();
        return NULL;
    }

    // Get frame rate
    UINT32 numerator = 0, denominator = 0;
    hr = MFGetAttributeRatio(nativeType, MF_MT_FRAME_RATE, &numerator, &denominator);
    
    double fps = 30.0;
    if (SUCCEEDED(hr) && denominator > 0) {
        fps = (double)numerator / (double)denominator;
    }

    // Get frame dimensions
    UINT32 width = 0, height = 0;
    MFGetAttributeSize(nativeType, MF_MT_FRAME_SIZE, &width, &height);
    nativeType->Release();

    if (width == 0 || height == 0) {
        reader->Release();
        return NULL;
    }

    // Configure the reader to output RGB32
    IMFMediaType* outputType = NULL;
    hr = MFCreateMediaType(&outputType);
    if (FAILED(hr)) {
        reader->Release();
        return NULL;
    }

    outputType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    outputType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    
    hr = reader->SetCurrentMediaType(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        NULL,
        outputType
    );
    outputType->Release();

    if (FAILED(hr)) {
        reader->Release();
        return NULL;
    }

    // Calculate timestamp for the frame (in 100-nanosecond units)
    LONGLONG timestamp = (LONGLONG)((double)frame_num / fps * 10000000.0);

    // Seek to the desired position
    PROPVARIANT seekPos;
    PropVariantInit(&seekPos);
    seekPos.vt = VT_I8;
    seekPos.hVal.QuadPart = timestamp;
    
    hr = reader->SetCurrentPosition(GUID_NULL, seekPos);
    PropVariantClear(&seekPos);

    if (FAILED(hr)) {
        reader->Release();
        return NULL;
    }

    // Read the sample
    IMFSample* sample = NULL;
    DWORD streamFlags = 0;
    
    hr = reader->ReadSample(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        0,
        NULL,
        &streamFlags,
        NULL,
        &sample
    );

    if (FAILED(hr) || sample == NULL || (streamFlags & MF_SOURCE_READERF_ENDOFSTREAM)) {
        if (sample) sample->Release();
        reader->Release();
        return NULL;
    }

    // Get the buffer from the sample
    IMFMediaBuffer* buffer = NULL;
    hr = sample->ConvertToContiguousBuffer(&buffer);
    
    if (FAILED(hr) || buffer == NULL) {
        sample->Release();
        reader->Release();
        return NULL;
    }

    BYTE* rawData = NULL;
    DWORD rawLength = 0;
    hr = buffer->Lock(&rawData, NULL, &rawLength);

    if (FAILED(hr) || rawData == NULL) {
        buffer->Release();
        sample->Release();
        reader->Release();
        return NULL;
    }

    // Encode to JPEG using WIC
    IWICImagingFactory* wicFactory = NULL;
    hr = CoCreateInstance(
        CLSID_WICImagingFactory,
        NULL,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&wicFactory)
    );

    unsigned char* jpegData = NULL;

    if (SUCCEEDED(hr) && wicFactory != NULL) {
        // Create bitmap from raw data
        IWICBitmap* bitmap = NULL;
        hr = wicFactory->CreateBitmapFromMemory(
            width, height,
            GUID_WICPixelFormat32bppBGRA,
            width * 4,
            rawLength,
            rawData,
            &bitmap
        );

        if (SUCCEEDED(hr) && bitmap != NULL) {
            // Create stream for JPEG output
            IStream* stream = NULL;
            hr = CreateStreamOnHGlobal(NULL, TRUE, &stream);

            if (SUCCEEDED(hr) && stream != NULL) {
                // Create JPEG encoder
                IWICBitmapEncoder* encoder = NULL;
                hr = wicFactory->CreateEncoder(
                    GUID_ContainerFormatJpeg,
                    NULL,
                    &encoder
                );

                if (SUCCEEDED(hr) && encoder != NULL) {
                    hr = encoder->Initialize(stream, WICBitmapEncoderNoCache);

                    if (SUCCEEDED(hr)) {
                        IWICBitmapFrameEncode* frame = NULL;
                        IPropertyBag2* props = NULL;
                        hr = encoder->CreateNewFrame(&frame, &props);

                        if (SUCCEEDED(hr) && frame != NULL) {
                            hr = frame->Initialize(props);
                            
                            if (SUCCEEDED(hr)) {
                                hr = frame->SetSize(width, height);
                            }
                            
                            if (SUCCEEDED(hr)) {
                                WICPixelFormatGUID pixelFormat = GUID_WICPixelFormat32bppBGRA;
                                hr = frame->SetPixelFormat(&pixelFormat);
                            }

                            if (SUCCEEDED(hr)) {
                                hr = frame->WriteSource(bitmap, NULL);
                            }

                            if (SUCCEEDED(hr)) {
                                hr = frame->Commit();
                            }

                            if (SUCCEEDED(hr)) {
                                hr = encoder->Commit();
                            }

                            if (SUCCEEDED(hr)) {
                                // Get the JPEG data from the stream
                                STATSTG stat;
                                hr = stream->Stat(&stat, STATFLAG_NONAME);
                                
                                if (SUCCEEDED(hr)) {
                                    DWORD jpegSize = (DWORD)stat.cbSize.QuadPart;
                                    jpegData = (unsigned char*)malloc(jpegSize);
                                    
                                    if (jpegData != NULL) {
                                        LARGE_INTEGER li = {0};
                                        stream->Seek(li, STREAM_SEEK_SET, NULL);
                                        
                                        ULONG bytesRead = 0;
                                        hr = stream->Read(jpegData, jpegSize, &bytesRead);
                                        
                                        if (SUCCEEDED(hr)) {
                                            *out_size = (int)bytesRead;
                                        } else {
                                            free(jpegData);
                                            jpegData = NULL;
                                        }
                                    }
                                }
                            }

                            if (props) props->Release();
                            frame->Release();
                        }
                    }
                    encoder->Release();
                }
                stream->Release();
            }
            bitmap->Release();
        }
        wicFactory->Release();
    }

    buffer->Unlock();
    buffer->Release();
    sample->Release();
    reader->Release();

    return jpegData;
}

// Free frame data
extern "C" void free_frame(unsigned char* data) {
    if (data) {
        free(data);
    }
}

#endif // _WIN32
