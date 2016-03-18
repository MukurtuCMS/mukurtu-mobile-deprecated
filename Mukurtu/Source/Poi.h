//
//  Poi.h
//
//MukurtuMobile
//Mukurtu Mobile is a mobile authoring tool for Mukurtu CMS, a digital
//heritage management system designed with the needs of indigenous
//communities in mind.
//http://mukurtumobile.org/
//Copyright (C) 2012-2016  CoDA https://codifi.org
//
//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class PoiCategory, PoiCommunity, PoiCulturalProtocol, PoiKeyword, PoiMedia;

@interface Poi : NSManagedObject

@property (nonatomic, retain) NSString * traditionalKnowledge;
@property (nonatomic, retain) NSString * creator;
@property (nonatomic, retain) NSString * street;
@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) NSString * telephone;
@property (nonatomic, retain) NSNumber * public;
@property (nonatomic, retain) NSString * locationLat;
@property (nonatomic, retain) NSString * firstThumbnail;
@property (nonatomic, retain) NSString * key;
@property (nonatomic, retain) NSString * formattedAddress;
@property (nonatomic, retain) NSString * streetnum;
@property (nonatomic, retain) NSString * keywordsString;
@property (nonatomic, retain) NSString * website;
@property (nonatomic, retain) NSNumber * value;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * culturalNarrative;
@property (nonatomic, retain) NSString * openingtime;
@property (nonatomic, retain) NSNumber * zip;
@property (nonatomic, retain) NSString * city;
@property (nonatomic, retain) NSString * longdescription;
@property (nonatomic, retain) NSString * price;
@property (nonatomic, retain) NSNumber * expectedSize;
@property (nonatomic, retain) NSNumber * sharingProtocol;
@property (nonatomic, retain) NSString * owner;
@property (nonatomic, retain) NSNumber * uploadedSize;
@property (nonatomic, retain) NSString * creationDateString;
@property (nonatomic, retain) NSDate * creationDate;
@property (nonatomic, retain) NSString * contributor;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * rating;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * locationLong;
@property (nonatomic, retain) NSSet *communities;
@property (nonatomic, retain) NSSet *media;
@property (nonatomic, retain) NSSet *categories;
@property (nonatomic, retain) NSSet *culturalProtocols;
@end

@interface Poi (CoreDataGeneratedAccessors)

- (void)addCommunitiesObject:(PoiCommunity *)value;
- (void)removeCommunitiesObject:(PoiCommunity *)value;
- (void)addCommunities:(NSSet *)values;
- (void)removeCommunities:(NSSet *)values;

- (void)addMediaObject:(PoiMedia *)value;
- (void)removeMediaObject:(PoiMedia *)value;
- (void)addMedia:(NSSet *)values;
- (void)removeMedia:(NSSet *)values;

- (void)addCategoriesObject:(PoiCategory *)value;
- (void)removeCategoriesObject:(PoiCategory *)value;
- (void)addCategories:(NSSet *)values;
- (void)removeCategories:(NSSet *)values;

- (void)addCulturalProtocolsObject:(PoiCulturalProtocol *)value;
- (void)removeCulturalProtocolsObject:(PoiCulturalProtocol *)value;
- (void)addCulturalProtocols:(NSSet *)values;
- (void)removeCulturalProtocols:(NSSet *)values;


@end
