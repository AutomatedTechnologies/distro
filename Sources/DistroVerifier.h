//
//  DistroVerifier.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  SHA-256 file verification (charter §5). Computes the digest of a file
//  by streaming it through CommonCrypto — never loads the file into
//  memory, so multi-hundred-megabyte packages verify in constant space —
//  and compares against the catalog's expected hex in constant time.
//
//  No third-party code. CommonCrypto is part of the OS on 10.13.
//

#import <Foundation/Foundation.h>

@interface DistroVerifier : NSObject

// Lowercase hex SHA-256 of the file at path, or nil on error
// (error set when non-nil-safe to inspect).
+ (NSString *)sha256HexOfFileAtPath:(NSString *)path error:(NSError **)error;

// YES iff the file at path hashes to expectedHex. The comparison runs
// in constant time over the digest bytes (no early exit) after a
// length check; a malformed expectedHex returns NO.
+ (BOOL)fileAtPath:(NSString *)path matchesSHA256Hex:(NSString *)expectedHex error:(NSError **)error;

@end
