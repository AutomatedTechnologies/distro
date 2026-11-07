//
//  DistroVerifier.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroVerifier.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const DistroVerifierErrorDomain = @"org.detroitautomationacademy.distro.verifier";
static const NSUInteger DistroVerifierChunkSize = 64 * 1024;

// Computes the raw 32-byte digest. Returns YES on success.
static BOOL DistroDigestOfFile(NSString *path, unsigned char digest[CC_SHA256_DIGEST_LENGTH], NSError **error) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil) {
        if (error) *error = [NSError errorWithDomain:DistroVerifierErrorDomain code:1
            userInfo:[NSDictionary dictionaryWithObject:@"File cannot be opened for reading."
                                                 forKey:NSLocalizedDescriptionKey]];
        return NO;
    }
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    for (;;) {
        NSData *chunk = [handle readDataOfLength:DistroVerifierChunkSize];
        if ([chunk length] == 0) break;
        CC_SHA256_Update(&ctx, [chunk bytes], (CC_LONG)[chunk length]);
    }
    [pool drain];
    [handle closeFile];
    CC_SHA256_Final(digest, &ctx);
    return YES;
}

// Decodes 64 hex chars into 32 bytes. Returns NO on any non-hex char.
static BOOL DistroBytesFromHex(NSString *hex, unsigned char bytes[CC_SHA256_DIGEST_LENGTH]) {
    if ([hex length] != CC_SHA256_DIGEST_LENGTH * 2) return NO;
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        unsigned int value = 0;
        NSString *pair = [hex substringWithRange:NSMakeRange(i * 2, 2)];
        NSScanner *scanner = [NSScanner scannerWithString:pair];
        if (![scanner scanHexInt:&value]) return NO;
        bytes[i] = (unsigned char)value;
    }
    return YES;
}

@implementation DistroVerifier

+ (NSString *)sha256HexOfFileAtPath:(NSString *)path error:(NSError **)error {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    if (!DistroDigestOfFile(path, digest, error)) return nil;
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

+ (BOOL)fileAtPath:(NSString *)path matchesSHA256Hex:(NSString *)expectedHex error:(NSError **)error {
    unsigned char expected[CC_SHA256_DIGEST_LENGTH];
    if (expectedHex == nil || !DistroBytesFromHex(expectedHex, expected)) {
        if (error) *error = [NSError errorWithDomain:DistroVerifierErrorDomain code:2
            userInfo:[NSDictionary dictionaryWithObject:@"Expected hash is not a valid SHA-256 hex string."
                                                 forKey:NSLocalizedDescriptionKey]];
        return NO;
    }
    unsigned char actual[CC_SHA256_DIGEST_LENGTH];
    if (!DistroDigestOfFile(path, actual, error)) return NO;
    // Constant-time compare: accumulate every byte difference, decide once.
    unsigned char diff = 0;
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        diff |= (unsigned char)(actual[i] ^ expected[i]);
    }
    return diff == 0;
}

@end
