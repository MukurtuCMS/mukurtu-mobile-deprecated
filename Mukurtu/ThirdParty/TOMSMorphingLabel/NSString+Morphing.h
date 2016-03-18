//
//  NSString+Morphing.h
//  TOMSMorphingLabelExample
//
//  Created by Tom König on 13/06/14.
//  Copyright (c) 2014 TomKnig. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kTOMSDictionaryKeyMergedString @"mergedString"
#define kTOMSDictionaryKeyAdditionRanges @"additionRanges"
#define kTOMSDictionaryKeyDeletionRanges @"deletionRanges"

@interface NSString (Morphing)

- (NSDictionary *)toms_mergeIntoString:(NSString *)string;

- (NSDictionary *)toms_mergeIntoString:(NSString *)string lookAheadRadius:(NSUInteger)lookAheadRadius;

@end
