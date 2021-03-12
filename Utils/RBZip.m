//
//  RBZip.m
//  RadBlock
//
//  Created by Mike Pulaski on 05/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <zlib.h>
#import "RBZip.h"

@implementation RBZip

+ (BOOL)deflateData:(NSData *)data toFileURL:(NSURL *)outputURL error:(NSError **)outError {
    FILE *output = fopen(outputURL.fileSystemRepresentation, "w");
    NSError *error = nil;
    
    if (output == NULL) {
        error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{
            NSFilePathErrorKey: outputURL.path,
            NSUnderlyingErrorKey: [NSError errorWithDomain:NSOSStatusErrorDomain code:errno userInfo:nil]
        }];
    } else {
        NSInputStream *input = [NSInputStream inputStreamWithData:data];
        [input open];
        error = _normalizeError(_deflate(input, output, Z_DEFAULT_COMPRESSION), nil, nil, outputURL);
        [input close];
    }
    
    if (output != NULL) {
        fclose(output);
    }
    
    if (outError != NULL) {
        (*outError) = error;
    }
    
    return error == nil;
}

+ (BOOL)inflateContentsOfFileURL:(NSURL *)inputURL toFileURL:(NSURL *)outputURL error:(NSError *__nullable *__nullable)outError {
    NSError *error = nil;
    FILE *input = NULL;
    FILE *output = NULL;
    
    if ((input = fopen(inputURL.fileSystemRepresentation, "r")) == NULL) {
        error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:@{
            NSFilePathErrorKey: outputURL.path,
            NSUnderlyingErrorKey: [NSError errorWithDomain:NSOSStatusErrorDomain code:errno userInfo:nil]
        }];
    } else if ((output = fopen(outputURL.fileSystemRepresentation, "w")) == NULL) {
        error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{
            NSFilePathErrorKey: outputURL.path,
            NSUnderlyingErrorKey: [NSError errorWithDomain:NSOSStatusErrorDomain code:errno userInfo:nil]
        }];
    } else {
        error = _normalizeError(_inflate(input, output), input, inputURL, outputURL);
    }
    
    if (input != NULL) {
        fclose(input);
    }
    
    if (output != NULL) {
        fclose(output);
    }
    
    if (outError != NULL) {
        (*outError) = error;
    }
    
    return error == nil;
}

static NSError *_normalizeError(int status, FILE *input, NSURL *inputURL, NSURL *outputURL) {
    switch (status) {
    case Z_ERRNO:
        if (input != NULL && inputURL != nil && ferror(input)) {
            return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:@{NSFilePathErrorKey: inputURL.path}];
        } else {
            return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{NSFilePathErrorKey: outputURL.path}];
        }
    case Z_STREAM_ERROR:
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
    case Z_DATA_ERROR:
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:EFTYPE userInfo:nil];
    case Z_MEM_ERROR:
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
    case Z_VERSION_ERROR:
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOEXEC userInfo:nil];
    default:
        return nil;
    }
}

// From https://zlib.net/zpipe.c

#define CHUNK 16384

static int _inflate(FILE *source, FILE *dest)
{
    int ret;
    unsigned have;
    z_stream strm;
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];

    /* allocate inflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = 0;
    strm.next_in = Z_NULL;
    ret = inflateInit(&strm);
    if (ret != Z_OK)
        return ret;

    /* decompress until deflate stream ends or end of file */
    do {
        strm.avail_in = (unsigned int)fread(in, 1, CHUNK, source);
        if (ferror(source)) {
            (void)inflateEnd(&strm);
            return Z_ERRNO;
        }
        if (strm.avail_in == 0)
            break;
        strm.next_in = in;

        /* run inflate() on input until output buffer not full */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;
            ret = inflate(&strm, Z_NO_FLUSH);
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            switch (ret) {
            case Z_NEED_DICT:
                ret = Z_DATA_ERROR;     /* and fall through */
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
                (void)inflateEnd(&strm);
                return ret;
            }
            have = CHUNK - strm.avail_out;
            if (fwrite(out, 1, have, dest) != have || ferror(dest)) {
                (void)inflateEnd(&strm);
                return Z_ERRNO;
            }
        } while (strm.avail_out == 0);

        /* done when inflate() says it's done */
    } while (ret != Z_STREAM_END);

    /* clean up and return */
    (void)inflateEnd(&strm);
    return ret == Z_STREAM_END ? Z_OK : Z_DATA_ERROR;
}

static int _deflate(NSInputStream *source, FILE *dest, int level)
{
    int ret, flush;
    unsigned have;
    z_stream strm;
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];

    /* allocate deflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    ret = deflateInit(&strm, level);
    if (ret != Z_OK)
        return ret;

    /* compress until end of file */
    do {
        strm.avail_in = (unsigned int)[source read:in maxLength:CHUNK];
        if (source.streamError != nil) {
            (void)deflateEnd(&strm);
            return Z_ERRNO;
        }
        flush = !source.hasBytesAvailable ? Z_FINISH : Z_NO_FLUSH;
        strm.next_in = in;

        /* run deflate() on input until output buffer not full, finish
           compression if all of source has been read in */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;
            ret = deflate(&strm, flush);    /* no bad return value */
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            have = CHUNK - strm.avail_out;
            if (fwrite(out, 1, have, dest) != have || ferror(dest)) {
                (void)deflateEnd(&strm);
                return Z_ERRNO;
            }
        } while (strm.avail_out == 0);
        assert(strm.avail_in == 0);     /* all input will be used */

        /* done when last data in file processed */
    } while (flush != Z_FINISH);
    assert(ret == Z_STREAM_END);        /* stream will be complete */

    /* clean up and return */
    (void)deflateEnd(&strm);
    return Z_OK;
}

@end

