//
//  MetadataTableViewController.h
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

@protocol MetadataContainerControllerDelegate <NSObject>

@required
-(CGRect)getContainerViewFrame;

@end

@interface MetadataTableViewController : UITableViewController
{
}

@property (nonatomic, weak) UIViewController<MetadataContainerControllerDelegate> *parentContainer;

@property (nonatomic, strong) NSMutableSet *selectedCommunities;
@property (nonatomic, strong) NSMutableSet *selectedCulturalProtocols;
@property (nonatomic, strong) NSMutableSet *selectedCategories;
@property (nonatomic, strong) UITextField *creationDateTextField;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) UIButton *calendarButton;
@property (nonatomic, assign) BOOL dateIsString;

//handle contributor and creator as token fields
@property (nonatomic, strong) NSString *contributorString;
@property (nonatomic, strong) NSString *creatorString;

- (void) loadMetadataFromPoi:(Poi *)poi;

@end
