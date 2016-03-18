//
//  Poi+clonePoiTo.m
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

#import "Poi+clonePoiTo.h"

@implementation Poi (clonePoiTo)

- (Poi *)clonePoiTo:(Poi*)poi
{
    DLog(@"Cloning poi %@", self.title);
    
    //copy with zone objects
    poi.traditionalKnowledge =  [self.traditionalKnowledge copy];
    poi.creator =  [self.creator copy];
    poi.locationLat =  [self.locationLat copy];
    poi.firstThumbnail =  [self.firstThumbnail copy];
    poi.key = [self.key copy];
    poi.formattedAddress =  [self.formattedAddress copy];
    poi.keywordsString =  [self.keywordsString copy];
    poi.culturalNarrative =  [self.culturalNarrative copy];
    poi.longdescription =  [self.longdescription copy];
    poi.expectedSize =  [self.expectedSize copy];
    poi.sharingProtocol =  [self.sharingProtocol copy];
    poi.owner =  [self.owner copy];
    poi.uploadedSize =  [self.uploadedSize copy];
    poi.creationDateString =  [self.creationDateString copy];
    poi.creationDate =  [self.creationDate copy];
    poi.contributor =  [self.contributor copy];
    poi.title =  [self.title copy];
    poi.timestamp =  [self.timestamp copy];
    poi.locationLong =  [self.locationLong copy];
    
    //relationship nullify
    poi.communities =  [NSSet setWithSet:self.communities];
    poi.categories =  [NSSet setWithSet:self.categories];
    //poi.keywords =  [NSSet setWithSet:self.keywords];
    poi.culturalProtocols = [NSSet setWithSet:self.culturalProtocols];
    
//#warning don't touch parent relationship of media object by now, sohould be confirmed by saving
    //warning! this will detach media from original poi, remember to handle it or they'll get lost!
    poi.media =  [NSSet setWithSet:self.media];
    self.media = nil;
    
    
    
    
    //not used
    //poi.street =  self.street
    //poi.country =  self.country
    //poi.state =  self.state
    //poi.telephone =  self.telephone
    //poi.public =  self.public
    //poi.streetnum =  self.streetnum
    //poi.website =  self.website
    //poi.value =  self.value
    //poi.email =  self.email
    //poi.openingtime =  self.openingtime
    //poi.zip =  self.zip
    //poi.city =  self.city
    //poi.price =  self.price
    //poi.rating =  self.rating copy];
    
    
    return poi;
}

@end
