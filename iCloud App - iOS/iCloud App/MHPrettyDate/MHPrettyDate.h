//
//  MHPrettyDate.h
//  MHPrettyDate
//
//  Created by Bobby Williams on 9/8/12.
//  Copyright (c) 2012 Bobby Williams. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>

typedef enum
{
    MHPrettyDateFormatWithTime,
    //
    //  EXAMPLE:  if today is September 30, 2012 and the time is 12:58 PM
    //     Today:        12:58 PM
    //     Tomorrow:     Tomorrow 12:58 PM
    //     Yesterday:    Yesterday 12:58 PM
    //     2 days ago:   Friday 12:58 PM
    //     1 week ago:   09/23/12 12:58 PM
    //     1 week later: 10/07/12 12:58 PM
    //
    MHPrettyDateFormatNoTime,
    //
    //  EXAMPLE:  if today is September 30, 2012 and the time is 12:58 PM
    //     Today:        Today
    //     Tomorrow:     Tomorrow
    //     Yesterday:    Yesterday
    //     2 days ago:   Friday
    //     1 week ago:   09/23/12
    //     1 week later: 10/07/12
    //
    MHPrettyDateFormatTodayTimeOnly,
    //
    //  EXAMPLE:  if today is September 30, 2012 and the time is 12:58 PM
    //     Today:        12:58 PM
    //     Tomorrow:     Tomorrow
    //     Yesterday:    Yesterday
    //     2 days ago:   Friday
    //     1 week ago:   09/23/12
    //     1 week later: 10/07/12
    //
    MHPrettyDateLongRelativeTime,
    //
    //  EXAMPLES:
    //     Now
    //     15 minutes ago
    //     59 minutes ago
    //     1 hour ago
    //     2 hours ago
    //     Yesterday
    //     30 days ago
    //     90 days ago
    //
    //     (future times same as MHPrettyDateFormatWithTime)
    //
   MHPrettyDateShortRelativeTime
   //
   //  EXAMPLES:
   //     Now
   //     15m
   //     59m
   //     1h
   //     23h
   //     1d
   //     30d
   //     90d
   //
   //     (future time but today same as MHPrettyDateFormatWithTime, otherwise same as MHPrettyDateFormatNoTime)
   //
} MHPrettyDateFormat;

@interface MHPrettyDate : NSObject

+(NSString*) prettyDateFromDate:(NSDate*) date withFormat:(MHPrettyDateFormat) dateFormat;
+(NSString*) prettyDateFromDate:(NSDate*) date withFormat:(MHPrettyDateFormat) dateFormat withDateStyle:(NSDateFormatterStyle) dateStyle;
+(NSString*) prettyDateFromDate:(NSDate*) date withFormat:(MHPrettyDateFormat) dateFormat withDateStyle:(NSDateFormatterStyle) dateStyle withTimeStyle:(NSDateFormatterStyle) timeStyle;
+(BOOL)      isToday:(NSDate*)       date;
// date
+(BOOL)      isPastDate:(NSDate*)     date;
+(BOOL)      isFutureDate:(NSDate*)   date;
+(BOOL)      isTomorrow:(NSDate*)     date;
+(BOOL)      isYesterday:(NSDate*)    date;
+(BOOL)      isWithinWeek:(NSDate*)   date;
+(BOOL)      willMakePretty:(NSDate*) date;
// time
+(BOOL)      isNow:(NSDate*)          date;
+(BOOL)      isFutureTime:(NSDate*)   date;
+(BOOL)      isPastTime:(NSDate*)     date;
+(BOOL)      isWithin24Hours:(NSDate*)date;
+(BOOL)      isWithinHour:(NSDate*)   date;

@end
