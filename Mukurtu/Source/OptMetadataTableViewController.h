//
//  OptMetadataTableViewController.h
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

#import <UIKit/UIKit.h>

@class Poi;
@class PSPDFTextView;
@class IphoneCreatePoiOptionalViewController;

@protocol OptMetadataContainerControllerDelegate <NSObject>
@required
-(void)childControllerBeginEdit;

@end

@interface OptMetadataTableViewController : UITableViewController
@property (nonatomic, strong) PSPDFTextView *descriptionTextView;
@property (nonatomic, strong) PSPDFTextView *culturalNarrativeTextView;

@property (nonatomic, copy) NSString *poiDescription;
@property (nonatomic, copy) NSString *culturalNarrative;
@property (nonatomic, copy) NSString *keywords;

@property (nonatomic, weak) IphoneCreatePoiOptionalViewController<OptMetadataContainerControllerDelegate> *parentContainer;

-(void) editDoneButtonPressed;

- (void) loadOptionaMetadataFromPoi:(Poi *)poi;

@end
