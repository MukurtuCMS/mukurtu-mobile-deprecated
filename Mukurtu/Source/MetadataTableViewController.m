//
//  MetadataTableViewController.m
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

#import "MetadataTableViewController.h"
#import "MukurtuSession.h"

#import "Poi.h"
#import "PoiCategory.h"
#import "PoiCulturalProtocol.h"
#import "PoiCommunity.h"
#import "PoiKeyword.h"
#import "PoiContributor.h"
#import "PoiCreator.h"
#import "PoiMedia.h"

//FIX 2.5: added custom ui control to handle contributor and creator
#import "JSTokenField.h"
#import "TOMSSuggestionBar.h"

//FIX 2.5: ios8 does not support datepicker inside an action sheet, use an alternative
#import "ActionSheetPicker.h"

#define kMukurtuRequiredMetadataNumberOfSections 6
#define kMukurtuSectionIndexCategories 2
#define kMukurtuSectionIndexCommunities 0
#define kMukurtuSectionIndexCulturalProtocols 1
#define kMukurtuSectionIndexSharingProtocol 7 //not used by now
#define kMukurtuSectionIndexCreator 3
#define kMukurtuSectionIndexContributor 4
#define kMukurtuSectionIndexDate 5


#define kCharCounterTag 101
#define CHARCOUNTER(a) ((UILabel *) [[ a leftView] viewWithTag:101])
#define kMaxDateChar 10

//#define kMukurtuSharingProtocolDefault 0
//#define kMukurtuSharingProtocolOpen 1
//#define kMukurtuSharingProtocolCommunity  2
//
//#define kMukurtuSharingProtocolDefaultText @"Use group defaults"
//#define kMukurtuSharingProtocolOpenText @"Open - accessible to all site users"
//#define kMukurtuSharingProtocolCommunityText  @"Community - accessible only to group members"


@interface MetadataTableViewController ()<UITextFieldDelegate, JSTokenFieldDelegate, TOMSSuggestionDelegate>
{
    BOOL dateIsString;
    
    NSInteger selectedSharingProtocol;

    CGRect containerViewFrame;
    
    MukurtuSession *_sharedSession;
    
}


@property (weak, nonatomic, readonly) MukurtuSession* sharedSession;

//FIX 2.5: ios8 does not support datepicker inside an action sheet, use an alternative
@property (nonatomic, strong) AbstractActionSheetPicker *actionSheetPicker;

//FIX 2.5: added custom ui control to handle contributor and creator
@property (nonatomic, strong) NSMutableArray *contributorTokens;
@property (nonatomic, strong) JSTokenField *contributorTokenField;
@property (nonatomic, strong) NSMutableArray *creatorTokens;
@property (nonatomic, strong) JSTokenField *creatorTokenField;

@end

@implementation MetadataTableViewController

@synthesize dateIsString = dateIsString;

///Helpers
- (void) errorAlert:(NSString *) message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error!" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];
}

- (void) updateCharCounterLabel:(UITextField *)textField numChar:(NSInteger)numChar
{
    UILabel *counterLabel = CHARCOUNTER(textField);
    counterLabel.text = [NSString stringWithFormat:@"%d", (int)(kMaxDateChar - numChar)];
}

- (UITextField *) createMetadataTextField
{
    UITextField *textField = [[UITextField alloc]initWithFrame:CGRectMake(kMukurtuMetadataTextFieldPadding, kMukurtuMetadataTextFieldPadding, CGRectGetWidth(containerViewFrame) - kMukurtuMetadataTextFieldPadding * 2, kMukurtuMetadataTextFieldHeight)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.clearsOnBeginEditing = NO;
    textField.textAlignment = NSTextAlignmentRight;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.keyboardType = UIKeyboardTypeNamePhonePad;
    textField.returnKeyType = UIReturnKeyDone;
    textField.delegate = self;
    
    return textField;
}

- (UIButton *) createCalendarButton
{
    //create calendar button to show date picker
    UIImage *imageCalendar = [UIImage imageNamed: @"calendar-icon.gif"];
    UIButton *btnCalendar = [UIButton buttonWithType:UIButtonTypeSystem];
    SEL selectorCalendarTap = NSSelectorFromString(@"calendarTap:");
    [btnCalendar addTarget:self action:selectorCalendarTap forControlEvents:UIControlEventTouchUpInside];
    
    [btnCalendar setBackgroundImage:imageCalendar forState:UIControlStateNormal];
    btnCalendar.frame = CGRectMake(0, 0, imageCalendar.size.width, imageCalendar.size.height);
    
    if (dateIsString)
        btnCalendar.enabled = NO;
    
    return btnCalendar;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    containerViewFrame = [self.parentContainer getContainerViewFrame];
    DLog(@"Container View Frame for metadata %@", NSStringFromCGRect(containerViewFrame));
    
    
    //FIX 2.5: added custom ui control to handle tokens for contributor and creator
    //contributor
    self.contributorTokens = [NSMutableArray array];
    self.contributorTokenField = [[JSTokenField alloc] initWithFrame:CGRectMake(0, 0, containerViewFrame.size.width, 31)];
    [self.contributorTokenField setDelegate:self];
    
    //creator
    self.creatorTokens = [NSMutableArray array];
    self.creatorTokenField = [[JSTokenField alloc] initWithFrame:CGRectMake(0, 0, containerViewFrame.size.width, 31)];
    [self.creatorTokenField setDelegate:self];
    
    //default to current username
    NSString *username = [[[MukurtuSession sharedSession] storedUsername] copy];
    
    if ([username length])
    {
        NSString *tokenId = [self getTokenIdForString:username];
        [self.creatorTokenField addTokenWithTitle:username representedObject:tokenId];
    }
    
    //observe tokenfields frame changes to handle dynamic table rows height
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tokenFieldFrameChanged:)
                                                 name:JSTokenFieldFrameDidChangeNotification
                                               object:nil];

    
    //sharing protocol
    //if ([self.poi valueForKey:@"sharingProtocol"] != nil)
   // {
   //     selectedSharingProtocol = [[self.poi valueForKey:@"sharingProtocol"] intValue];
   //
   //     if (selectedSharingProtocol < 0 || selectedSharingProtocol > 2)
   //         selectedSharingProtocol = kMukurtuSharingProtocolDefault;
    //}
    //else
    selectedSharingProtocol = kMukurtuSharingProtocolDefault;
    
    //init calendar button
    self.calendarButton = [self createCalendarButton];


    //init creation date text field
    CGFloat btnWidth = CGRectGetWidth(self.calendarButton.frame);
    UITextField *textFieldCreationDateString = [self createMetadataTextField];
    textFieldCreationDateString.clearButtonMode = UITextFieldViewModeNever;
    textFieldCreationDateString.leftViewMode = UITextFieldViewModeAlways;
    textFieldCreationDateString.frame = CGRectMake(kMukurtuMetadataTextFieldPadding + btnWidth*2, kMukurtuMetadataTextFieldPadding, CGRectGetWidth(containerViewFrame) - kMukurtuMetadataTextFieldPadding * 2 - btnWidth*2, kMukurtuMetadataTextFieldHeight);
    [textFieldCreationDateString setPlaceholder:@"e.g. 1870"];
    
    //add char counter inside text field
    UILabel *charCounter = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 20.0, 18.0)];
    [charCounter setTextColor:[UIColor lightGrayColor]];
    [charCounter setText:[NSString stringWithFormat:@"%d", kMaxDateChar]];
    charCounter.tag = kCharCounterTag;
    textFieldCreationDateString.leftView = charCounter;
    
    //new poi defaults with current date selected
    dateIsString = NO;
    textFieldCreationDateString.enabled = NO;
    self.calendarButton.enabled = YES;
    
    textFieldCreationDateString.tag = kMukurtuSectionIndexDate;
    self.creationDateTextField = textFieldCreationDateString;
    self.creationDate = [NSDate date];
    
    
    //init selected groups
    _selectedCategories = [NSMutableSet set];
    _selectedCommunities = [NSMutableSet set];
    _selectedCulturalProtocols = [NSMutableSet set];
    
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.contributorTokenField updateBarFrame];
    
    [self.creatorTokenField updateBarFrame];
    
    
    if (![MukurtuSession sharedSession].serverCMSVersion1)
    {
        //defaults for iphone
        int numFields = 2;
        int fontSize = 16.0;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            numFields = 3;
            fontSize = 20.0;
        }
        
        //add contributor suggestions bar
        TOMSSuggestionBar *suggestionBar = [[TOMSSuggestionBar alloc] initWithNumberOfSuggestionFields:numFields];
        [suggestionBar subscribeTextInputView:self.contributorTokenField.textField
               toSuggestionsForAttributeNamed:@"name"
                                ofEntityNamed:@"PoiContributor"
                                 inModelNamed:@"Mukurtu2"];
        suggestionBar.font = [UIFont systemFontOfSize:fontSize];
        suggestionBar.delegate = self;
        
        
        //add contributor suggestions bar
        TOMSSuggestionBar *creatorSuggestionBar = [[TOMSSuggestionBar alloc] initWithNumberOfSuggestionFields:numFields];
        [creatorSuggestionBar subscribeTextInputView:self.creatorTokenField.textField
                      toSuggestionsForAttributeNamed:@"name"
                                       ofEntityNamed:@"PoiCreator"
                                        inModelNamed:@"Mukurtu2"];
        creatorSuggestionBar.font = [UIFont systemFontOfSize:fontSize];
        creatorSuggestionBar.delegate = self;
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (void) loadMetadataFromPoi:(Poi *)poi
{
    DLog(@"Loading metadata table from poi %@", poi.title);
    
    self.selectedCategories = [poi.categories mutableCopy];
    self.selectedCulturalProtocols = [poi.culturalProtocols mutableCopy];
    self.selectedCommunities = [poi.communities mutableCopy];
    
#warning sharing protocol fixed to default
    selectedSharingProtocol = kMukurtuSharingProtocolDefault;
    //selectedSharingProtocol = [poi.sharingProtocol intValue];
    
    /*
    self.contributorTextField.text = [poi.contributor copy];
    self.creatorTextField.text = [poi.creator copy];
    
    
    //default to current username
    NSString *username = [[[MukurtuSession sharedSession] storedUsername] copy];
    
    if ([poi.creator length] > 0)
        [self.creatorTextField setText:[poi.creator copy]];
    else
        if (![username isEqualToString:@""])
            [self.creatorTextField setText:username];
        else
            [self.creatorTextField setPlaceholder:@"Creator name"];
    */
    
    //FIX 2.5: creator and contributor uses token field, rebuild tokens
    //contributor
    if ([poi.contributor length])
    {
        NSArray *contributors;
        
        if ([MukurtuSession sharedSession].serverCMSVersion1)
        {
            contributors = [poi.contributor componentsSeparatedByString:@","];
        }
        else
        {
            contributors = [poi.contributor componentsSeparatedByString:@";"];
        }
        
        for (NSString *contributor in contributors)
        {
            if ([contributor length])
            {
                NSString *tokenId = [self getTokenIdForString:contributor];
                [self.contributorTokenField addTokenWithTitle:contributor representedObject:tokenId];
            }
        }
    }
    
    //creator
    if ([poi.creator length])
    {
        NSArray *creators;
        
        if ([MukurtuSession sharedSession].serverCMSVersion1)
        {
            creators = [poi.creator componentsSeparatedByString:@","];
        }
        else
        {
            creators = [poi.creator componentsSeparatedByString:@";"];
        }
        
        for (NSString *creator in creators)
        {
            if ([creator length])
            {
                NSString *tokenId = [self getTokenIdForString:creator];
                [self.creatorTokenField addTokenWithTitle:creator representedObject:tokenId];
            }
        }
    }
    
    DLog(@"Current poi creation date string: %@, date: %@",[poi.creationDateString copy], [NSDateFormatter localizedStringFromDate:poi.creationDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle]);
    
    if ([poi.creationDateString length] <= 0)
    {
        self.creationDate = [poi.creationDate copy];
        self.creationDateTextField.text = 0;
        self.creationDateTextField.enabled = NO;
        self.calendarButton.enabled = YES;
        self.dateIsString = NO;
    }
    else
    {
        self.creationDateTextField.text = [poi.creationDateString copy];
        self.creationDateTextField.enabled = YES;
        [self updateCharCounterLabel:self.creationDateTextField numChar:[self.creationDateTextField.text length]];
        self.calendarButton.enabled = NO;
        self.dateIsString = YES;
    }
    
    [self.tableView reloadData];
    
}

- (MukurtuSession*)sharedSession
{
    if (_sharedSession == nil)
    {
        _sharedSession = [MukurtuSession sharedSession];
    }
    
    return _sharedSession;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return kMukurtuRequiredMetadataNumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger numRows = 0;
    
    // Return the number of rows in the section.
    switch (section)
    {
        case kMukurtuSectionIndexCategories:
            numRows = [self.sharedSession.currentCategories count] ;
            break;
            
        case kMukurtuSectionIndexCommunities:
            numRows = [self.sharedSession.currentCommunities count];
            break;
            
        case kMukurtuSectionIndexCulturalProtocols:
            //FIX 2.5: support og hierarchy
            if (self.sharedSession.serverCMSVersion1)
            {
                numRows = [self.sharedSession.currentCulturalProtocols count];
            }
            else
            {
                NSMutableSet *availableCPSet = [NSMutableSet set];
                for (PoiCommunity *selectedCommunity in self.selectedCommunities)
                {
                    [availableCPSet unionSet:[self.sharedSession.currentGroupsTree valueForKey:[selectedCommunity.nid description]]];
                }
                
                numRows = [availableCPSet count];
            }
            break;
            
        case kMukurtuSectionIndexSharingProtocol:
            numRows = 3;
            break;
            
        case kMukurtuSectionIndexCreator:
            numRows = 1;
            break;
            
        case kMukurtuSectionIndexContributor:
            numRows = 1;
            break;
            
        case kMukurtuSectionIndexDate:
            numRows = 2;
            break;
            
        default:
            break;
    }
    
    return numRows;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifierGroup = @"MetadataCellGroup";
    static NSString *CellIdentifierTextField = @"MetadataCellTextField";
    static NSString *CellIdentifierDate = @"MetadataCellDate";
    
    UITableViewCell *cell;
    NSString *cellIdentifier;
    
    if ([indexPath section] == kMukurtuSectionIndexCategories ||
        [indexPath section] == kMukurtuSectionIndexCommunities ||
        [indexPath section] == kMukurtuSectionIndexCulturalProtocols ||
        [indexPath section] == kMukurtuSectionIndexSharingProtocol)
        cellIdentifier = CellIdentifierGroup;
    else
        if ([indexPath section] == kMukurtuSectionIndexCreator ||
            [indexPath section] == kMukurtuSectionIndexContributor)
            cellIdentifier = CellIdentifierTextField;
        else
            if ([indexPath section] == kMukurtuSectionIndexDate)
                cellIdentifier = CellIdentifierDate;
            else//default case to avoid drawing empty cells on bottom
                cellIdentifier = @"MetadataCellGeneric";
    
    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.font = [UIFont systemFontOfSize:kMukurtuMetadataFontSize];
        cell.textLabel.textColor = kMukurtuMetadataFontColor;
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.minimumScaleFactor = 0.6;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    PoiCategory *category;
    PoiCulturalProtocol *culturalProtocol;
    PoiCommunity *community;
    
    switch ([indexPath section])
    {
        case kMukurtuSectionIndexCategories:
            category = [self.sharedSession.currentCategories objectAtIndex:[indexPath row]];
            
            [cell.textLabel setText:category.name];
            
            if ([self.selectedCategories containsObject:category])
            {
                cell.imageView.image = [UIImage imageNamed:@"check_yes.png"];
                cell.tag = YES;
            }
            else
            {
                cell.imageView.image = [UIImage imageNamed:@"check_no.png"];
                cell.tag = NO;
            }
            break;
            
        case kMukurtuSectionIndexCommunities:
            community = [self.sharedSession.currentCommunities objectAtIndex:[indexPath row]];
            
            [cell.textLabel setText:community.title];
            
            if ([self.selectedCommunities containsObject:community])
            {
                cell.imageView.image = [UIImage imageNamed:@"check_yes.png"];
                cell.tag = YES;
            }
            else
            {
                cell.imageView.image = [UIImage imageNamed:@"check_no.png"];
                cell.tag = NO;
            }
            break;
            
        case kMukurtuSectionIndexCulturalProtocols:
            if (self.sharedSession.serverCMSVersion1)
            {
                culturalProtocol = [self.sharedSession.currentCulturalProtocols objectAtIndex:[indexPath row]];
            }
            else
            {
                NSMutableSet *availableCPSet = [NSMutableSet set];
                for (PoiCommunity *selectedCommunity in self.selectedCommunities)
                {
                    NSMutableSet *childrenCP = [NSMutableSet set];
                    for (NSString *cpNid in [self.sharedSession.currentGroupsTree valueForKey:[selectedCommunity.nid description]])
                    {
                        [childrenCP addObject:[PoiCulturalProtocol MR_findFirstByAttribute:@"nid" withValue:cpNid]];
                    }
                    
                    [availableCPSet unionSet:childrenCP];
                }
                
                NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]];
                culturalProtocol =  [[[availableCPSet allObjects] sortedArrayUsingDescriptors:sortDescriptors] objectAtIndex:[indexPath row]];
            }
            
            [cell.textLabel setText:culturalProtocol.title];
            
            if ([self.selectedCulturalProtocols containsObject:culturalProtocol])
            {
                cell.imageView.image = [UIImage imageNamed:@"check_yes.png"];
                cell.tag = YES;
            }
            else
            {
                cell.imageView.image = [UIImage imageNamed:@"check_no.png"];
                cell.tag = NO;
            }
            
            break;
            
        case kMukurtuSectionIndexCreator:
            //[cell.contentView addSubview:self.creatorTextField];
            [cell.contentView addSubview:self.creatorTokenField];
            break;
            
        case kMukurtuSectionIndexContributor:
            //[cell.contentView addSubview:self.contributorTextField];
            [cell.contentView addSubview:self.contributorTokenField];
            break;
            
        case kMukurtuSectionIndexDate:
        {
            //DLog(@"redrawing data row");
            
            if ([indexPath row] == 0)
            {
                //add date label to cell
                NSDateFormatter *df = [[NSDateFormatter alloc] init];;
                df.dateStyle = NSDateFormatterMediumStyle;
                NSString *dateLabel = [NSString stringWithFormat:@"%@",[df stringFromDate:self.creationDate]];
                cell.textLabel.font = [UIFont systemFontOfSize:kMukurtuMetadataFontSizeDate];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                [cell.textLabel setText:dateLabel];
                
                //add calendar button to cell in accessory view
                
                cell.accessoryType = UITableViewCellAccessoryDetailButton;
                self.calendarButton = [self createCalendarButton];
                cell.accessoryView = self.calendarButton;
            
                
                //set radio button image and tap handling
                if (dateIsString)
                    cell.imageView.image = [UIImage imageNamed:@"radio_btn_empty.png"];
                else
                    cell.imageView.image = [UIImage imageNamed:@"radio_btn_full.png"];
                
                SEL selectorDatePickerRowTap = NSSelectorFromString(@"datePickerRowTap:");
                [cell.imageView setUserInteractionEnabled:YES];
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selectorDatePickerRowTap];
                [tap setNumberOfTapsRequired:1];
                [cell.imageView setGestureRecognizers:[NSArray arrayWithObject:tap]];
            }
            else
            {
                //add text field (with char counter) to cell
                [cell.contentView addSubview:self.creationDateTextField];
                
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.accessoryView = nil;
                
                //set radio button image and tap handling
                if (dateIsString)
                    cell.imageView.image = [UIImage imageNamed:@"radio_btn_full.png"];
                else
                    cell.imageView.image = [UIImage imageNamed:@"radio_btn_empty.png"];
                
                [cell.imageView setUserInteractionEnabled:YES];
                SEL selectorDateStringRowTap = NSSelectorFromString(@"dateStringRowTap:");
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selectorDateStringRowTap];
                [tap setNumberOfTapsRequired:1];
                [cell.imageView setGestureRecognizers:[NSArray arrayWithObject:tap]];
                
            }
        }
            break;
            
        default:
            break;
    }
    
    
    return cell;
}

//FIXME height for row is really expensive, but setting tableView.rowHeight doesn't work: why?
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([indexPath section])
    {
        case kMukurtuSectionIndexCreator:
            return self.creatorTokenField.bounds.size.height;
            break;
            
        case kMukurtuSectionIndexContributor:
            return self.contributorTokenField.bounds.size.height;
            break;
            
        case kMukurtuSectionIndexDate:
            return (kMukurtuMetadataTextFieldHeight + kMukurtuMetadataTextFieldPadding * 2);
            break;
            
        default:
            return kMukurtuMetadataGroupRowHeight;
            break;
    }
    
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    
    NSString *sectionTitle;
    
    // Return the number of rows in the section.
    switch (section)
    {
        case kMukurtuSectionIndexCategories:
            //categories
            sectionTitle = @"CATEGORIES *";
            break;
            
        case kMukurtuSectionIndexCommunities:
            //communities
            sectionTitle = @"COMMUNITIES *";
            break;
            
        case kMukurtuSectionIndexCulturalProtocols:
            //cultural protocols
            sectionTitle = @"CULTURAL PROTOCOLS *";
            break;
            
        case kMukurtuSectionIndexSharingProtocol:
            //sharing protocol
            sectionTitle = @"SHARING PROTOCOL *";
            break;
            
        case kMukurtuSectionIndexCreator:
            //creator
            sectionTitle = @"CREATOR *";
            break;
            
        case kMukurtuSectionIndexContributor:
            //contributor
            sectionTitle = @"CONTRIBUTOR";
            break;
            
        case kMukurtuSectionIndexDate:
            //date
            sectionTitle = @"DATE *";
            break;
            
        default:
            sectionTitle = @"";
            break;
    }
    
    
    // create the parent view that will hold header Label
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(containerViewFrame), kMukurtuSectionHeaderHeight)];
    customView.backgroundColor = kUIColorOrange;
    
    // create the button object
    UIButton *btnHeader = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnHeader addTarget:self action:@selector(sectionHelpPressed:) forControlEvents:UIControlEventTouchUpInside];
    btnHeader.tag = section;
    
    UIImage *btnHeaderImage = [UIImage imageNamed:@"sectionInfoIcon.png"];
    [btnHeader setBackgroundImage:btnHeaderImage forState:UIControlStateNormal];
    [btnHeader setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    CGFloat padding = (kMukurtuSectionHeaderHeight - btnHeaderImage.size.height)/2;
    btnHeader.frame = CGRectMake((CGRectGetWidth(containerViewFrame) - btnHeaderImage.size.width - padding) ,
                                 padding,
                                 btnHeaderImage.size.width,
                                 btnHeaderImage.size.height);
    [customView addSubview:btnHeader];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    [titleLabel setText:sectionTitle];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.opaque = NO;
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0];
    titleLabel.frame = CGRectMake(2.0, 0.0, CGRectGetWidth(containerViewFrame), kMukurtuSectionHeaderHeight);
    [customView addSubview:titleLabel];
    
    return customView;
}


- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return kMukurtuSectionHeaderHeight;
}

- (void) sectionHelpPressed:(id)sender
{
    UIButton *button = sender;
    
    NSInteger section = button.tag;
    
    NSString *helpMessage;
    
    DLog(@"pressed help icon for header section %d", (int)section);
    
    switch (section)
    {
        case kMukurtuSectionIndexCategories:
            //categories
            helpMessage = @"Categories make it easier to browse and retrieve content.\nChoose one or more categories that best describe your story.\nDon't worry, you can always add more categories on your Mukurtu site, then sync to Mukurtu Mobile to apply to your story later.";
            break;
            
        case kMukurtuSectionIndexCommunities:
            //communities
            helpMessage = @"Select the communities that you would like to share your story with.\nDon't worry, you can always add more communties on your Mukurtu site, then sync to Mukurtu Mobile to apply to your story later.";
            break;
            
        case kMukurtuSectionIndexCulturalProtocols:
            //cultural protocols
            helpMessage = @"Select the cultural protocols associated with this story.\nYou will have to select at least one community in the list above to see your available cultural protocols.\nDon't worry, you can add more protocols on your Mukurtu site, then sync to Mukurtu Mobile to apply to your story later.";
            break;
            
        case kMukurtuSectionIndexSharingProtocol:
            //sharing protocol
            helpMessage = @"Choosing a sharing protocol will define who can access this item.";
            break;
            
        case kMukurtuSectionIndexCreator:
            //creator
            helpMessage = @"The creator of the story: for example, who took the picture, wrote the narrative, etc.\nUse \"Return\" to add a new value.";
            break;
            
        case kMukurtuSectionIndexContributor:
            //contributor
            helpMessage = @"Person(s) or organization(s) that contributed the content.\nUse \"Return\" to add a new value.";
            break;
            
        case kMukurtuSectionIndexDate:
            //date
            helpMessage = @"Date associated with the creation of the content – E.g.: date the story was written, date the photo was taken, etc.\nPick a date from calendar and insert textual information if you like.";
            break;
            
        default:
            helpMessage = @"";
            break;
    }
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Help" message:helpMessage delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];
    
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    switch ([indexPath section])
    {
        case kMukurtuSectionIndexCategories:
        case kMukurtuSectionIndexCommunities:
        case kMukurtuSectionIndexCulturalProtocols:
        {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            
            if (cell.tag == NO)
            {
                cell.tag = YES;
                cell.imageView.image = [UIImage imageNamed:@"check_yes.png"];
                
                switch ([indexPath section])
                {
                    case kMukurtuSectionIndexCategories:
                        //categories
                        [self.selectedCategories addObject:[_sharedSession.currentCategories objectAtIndex:[indexPath row]]];
                        //DLog(@"Adding category %@", [(PoiCategory *)[_sharedSession.currentCategories objectAtIndex:[indexPath row]] name]);
                        break;
                        
                    case kMukurtuSectionIndexCommunities:
                        //communities
                        [self.selectedCommunities addObject:[_sharedSession.currentCommunities objectAtIndex:[indexPath row]]];
                        
                        //FIX 2.5: reload table after community select/deselect to animate available CP insertion
                        if (!self.sharedSession.serverCMSVersion1)
                        {
                            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:kMukurtuSectionIndexCulturalProtocols] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        break;
                        
                    case kMukurtuSectionIndexCulturalProtocols:
                        //cultural protocols
                        //FIX 2.5: search selected cultural protocol in all cp available (take in account masking performed with communities selection)
                        if (self.sharedSession.serverCMSVersion1)
                        {
                            [self.selectedCulturalProtocols addObject:[_sharedSession.currentCulturalProtocols objectAtIndex:[indexPath row]]];
                        }
                        else
                        {
                            NSMutableSet *availableCPSet = [NSMutableSet set];
                            for (PoiCommunity *selectedCommunity in self.selectedCommunities)
                            {
                                NSMutableSet *childrenCP = [NSMutableSet set];
                                for (NSString *cpNid in [self.sharedSession.currentGroupsTree valueForKey:[selectedCommunity.nid description]])
                                {
                                    [childrenCP addObject:[PoiCulturalProtocol MR_findFirstByAttribute:@"nid" withValue:cpNid]];
                                }
                                
                                [availableCPSet unionSet:childrenCP];
                            }
                            
                            NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]];
                            
                            [self.selectedCulturalProtocols addObject:[[[availableCPSet allObjects]
                                                                        sortedArrayUsingDescriptors:sortDescriptors]
                                                                       objectAtIndex:[indexPath row]]];
                        }
                        break;
                        
                    default:
                        break;
                }
            }
            else
            {
                cell.imageView.image = [UIImage imageNamed:@"check_no.png"];
                cell.tag = NO;
                
                switch ([indexPath section])
                {
                    case kMukurtuSectionIndexCategories:
                        //categories
                        [self.selectedCategories removeObject:[_sharedSession.currentCategories objectAtIndex:[indexPath row]]];
                        break;
                        
                    case kMukurtuSectionIndexCommunities:
                        //communities
                        [self.selectedCommunities removeObject:[_sharedSession.currentCommunities objectAtIndex:[indexPath row]]];
                        
                        //FIX 2.5: reload table after community select/deselect to animate available CP insertion
                        if (!self.sharedSession.serverCMSVersion1)
                        {
                            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:kMukurtuSectionIndexCulturalProtocols] withRowAnimation:UITableViewRowAnimationAutomatic];
                            
                            //remove selection from any CP no more visible (parent community got deselected)
                            NSMutableSet *availableCPSet = [NSMutableSet set];
                            for (PoiCommunity *selectedCommunity in self.selectedCommunities)
                            {
                                NSMutableSet *childrenCP = [NSMutableSet set];
                                for (NSString *cpNid in [self.sharedSession.currentGroupsTree valueForKey:[selectedCommunity.nid description]])
                                {
                                    [childrenCP addObject:[PoiCulturalProtocol MR_findFirstByAttribute:@"nid" withValue:cpNid]];
                                }
                                
                                [availableCPSet unionSet:childrenCP];
                            }
                            
                            [self.selectedCulturalProtocols intersectSet:availableCPSet];
                        }
                        break;
                        
                    case kMukurtuSectionIndexCulturalProtocols:
                        //cultural protocols
                        //FIX 2.5: search selected cultural protocol in all cp available (take in account masking performed with communities selection)
                        if (self.sharedSession.serverCMSVersion1)
                        {
                            [self.selectedCulturalProtocols removeObject:[_sharedSession.currentCulturalProtocols objectAtIndex:[indexPath row]]];
                        }
                        else
                        {
                            NSMutableSet *availableCPSet = [NSMutableSet set];
                            for (PoiCommunity *selectedCommunity in self.selectedCommunities)
                            {
                                NSMutableSet *childrenCP = [NSMutableSet set];
                                for (NSString *cpNid in [self.sharedSession.currentGroupsTree valueForKey:[selectedCommunity.nid description]])
                                {
                                    [childrenCP addObject:[PoiCulturalProtocol MR_findFirstByAttribute:@"nid" withValue:cpNid]];
                                }
                                
                                [availableCPSet unionSet:childrenCP];
                            }
                            
                            NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]];
                            
                            [self.selectedCulturalProtocols removeObject:[[[availableCPSet allObjects]
                                                                        sortedArrayUsingDescriptors:sortDescriptors]
                                                                       objectAtIndex:[indexPath row]]];

                        }
                        break;
                        
                    default:
                        break;
                }
            }
            
            DLog(@"Selected metadata: Categories: %d, Communities: %d, Cult.Protocols: %d", (int)[_selectedCategories count], (int)[_selectedCommunities count], (int)[_selectedCulturalProtocols count]);
        }
            break;
        
        /*
        case kMukurtuSectionIndexSharingProtocol:
        {
            //UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            
            selectedSharingProtocol = [indexPath row];
            
            for (int i=0; i<3;i++)
            {
                NSIndexPath *indexP = [NSIndexPath indexPathForRow:i inSection:kMukurtuSectionIndexSharingProtocol];
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexP];
                
                if (i == selectedSharingProtocol)
                    cell.imageView.image = [UIImage imageNamed:@"radio_btn_full.png"];
                else
                    cell.imageView.image = [UIImage imageNamed:@"radio_btn_empty.png"];
            }
            
        }
            break;
        */
            
        case kMukurtuSectionIndexDate:
        {
            
        }
            break;
            
        default:
            break;
    }
    
}

- (void) dateStringRowTap:(UITapGestureRecognizer *)tap
{
    NSIndexPath *index0 = [NSIndexPath indexPathForRow:0 inSection:kMukurtuSectionIndexDate];
    NSIndexPath *index1 = [NSIndexPath indexPathForRow:1 inSection:kMukurtuSectionIndexDate];
    
    UITableViewCell *cellDatePicker = [self.tableView cellForRowAtIndexPath:index0];
    UITableViewCell *cellDateString = [self.tableView cellForRowAtIndexPath:index1];
    
    dateIsString = YES;
    cellDatePicker.imageView.image = [UIImage imageNamed:@"radio_btn_empty.png"];
    cellDateString.imageView.image = [UIImage imageNamed:@"radio_btn_full.png"];
    self.creationDateTextField.enabled = YES;
    cellDatePicker.textLabel.enabled = NO;
    self.calendarButton.enabled = NO;
    
    [self.creationDateTextField becomeFirstResponder];
}

- (void) datePickerRowTap:(UITapGestureRecognizer *)tap
{
    NSIndexPath *index0 = [NSIndexPath indexPathForRow:0 inSection:kMukurtuSectionIndexDate];
    NSIndexPath *index1 = [NSIndexPath indexPathForRow:1 inSection:kMukurtuSectionIndexDate];
    
    UITableViewCell *cellDatePicker = [self.tableView cellForRowAtIndexPath:index0];
    UITableViewCell *cellDateString = [self.tableView cellForRowAtIndexPath:index1];
    
    dateIsString = NO;
    cellDatePicker.imageView.image = [UIImage imageNamed:@"radio_btn_full.png"];
    cellDateString.imageView.image = [UIImage imageNamed:@"radio_btn_empty.png"];
    self.creationDateTextField.enabled = NO;
    cellDatePicker.textLabel.enabled = YES;
    self.calendarButton.enabled = YES;
    
    [self.creationDateTextField setText:nil];
    [self updateCharCounterLabel:self.creationDateTextField numChar:0];
}


- (void)calendarTap:(id)sender
{
    DLog(@"calendar tapped");
    
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDateComponents *minimumDateComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
    
    [minimumDateComponents setYear:0];
    
    NSDate *minDate = [calendar dateFromComponents:minimumDateComponents];
    
    NSDate *maxDate = [NSDate date];
    
    
    SEL selectorDateSelected = NSSelectorFromString(@"dateWasSelected:element:");
    _actionSheetPicker = [[ActionSheetDatePicker alloc] initWithTitle:@"" datePickerMode:UIDatePickerModeDate selectedDate:self.creationDate
                                                               target:self action:selectorDateSelected origin:sender];
    
    
    [(ActionSheetDatePicker *) self.actionSheetPicker setMinimumDate:minDate];
    [(ActionSheetDatePicker *) self.actionSheetPicker setMaximumDate:maxDate];
    
    
    [self.actionSheetPicker addCustomButtonWithTitle:@"Today" value:[NSDate date]];
    
    self.actionSheetPicker.hideCancel = YES;
    
    [self.actionSheetPicker showActionSheetPicker];

}

- (void)dateWasSelected:(NSDate *)selectedDate element:(id)element
{
    self.creationDate = selectedDate;
    [self.tableView reloadData];
}


////Text Field protocol
#pragma mark - TextField protocol

- (BOOL)textFieldShouldReturn:(UITextField *)aTextField
{
    //This removes the keyboard input
    [aTextField resignFirstResponder];
    
    return TRUE;
}

- (void) textFieldDidBeginEditing:(UITextField *)textField
{
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void) textFieldDidEndEditing:(UITextField *)textField
{
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    switch (textField.tag)
    {
        case kMukurtuSectionIndexCreator:
            if (textField.text == nil ||
                [textField.text length] == 0)
            {
                //default to current username
                NSString *username = [[[MukurtuSession sharedSession] storedUsername] copy];
                
                if (![username isEqualToString:@""])
                    [textField setText:username];
                else
                    [textField setPlaceholder:@"Creator name"];
            }
            break;
            
        case kMukurtuSectionIndexContributor: //contributor is not required, could be empty
            if ([textField.text length] == 0)
                textField.text = nil;
            
        default:
            break;
    }
    
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    int newLen;
    
    switch (textField.tag)
    {
        case kMukurtuSectionIndexDate:
            
            //DLog(@"range location %d, length %d",range.location, range.length);
            newLen = [textField.text length] + [string length] - range.length;
            if (newLen <= kMaxDateChar)
            {
                [self updateCharCounterLabel:self.creationDateTextField numChar:newLen];
                return YES;
            }
            else
                return NO;
            
            break;
        default:
            return TRUE;
            break;
    }
}


//FIX 2.5: added custom ui control to handle keywords
#pragma mark - TOMSSuggestionDelegate

- (void)suggestionBar:(TOMSSuggestionBar *)suggestionBar
  didSelectSuggestion:(NSString *)suggestion
     associatedObject:(NSManagedObject *)associatedObject
{
    JSTokenField *tokenField;
    
    if ([associatedObject isKindOfClass:[PoiContributor class]])
    {
        tokenField = self.contributorTokenField;
    }
    else if ([associatedObject isKindOfClass:[PoiCreator class]])
    {
        tokenField = self.creatorTokenField;
    }
    else
    {
        DLog(@"Wrong associated object %@, skip token", [associatedObject description]);
        return;
    }
    
    [tokenField.textField setText:@""];
    
    NSString *tokenId = [self getTokenIdForString:suggestion];
    
    if ([tokenId length])
    {
        [tokenField addTokenWithTitle:suggestion representedObject:tokenId];
    }
    
    if (tokenField.bounds.size.height > kTokenFieldTableRowMaxHeight - tokenField.textField.bounds.size.height)
    {
        [tokenField.textField resignFirstResponder];
    }
    
}

#pragma mark JSTokenField Delegate
//Checklist tokenField add on
//- skip already present keyword during add token *
//- skip add token if limit height set (e.g. ipad keyword tab) *
//- rebuild tokens on poi load *
//- skip ; from allowed text *
//- skin tokens colors bg image *
//- add suggestions on keyboard acessory input view (use https://github.com/TomKnig/TOMSSuggestionBar ) *
//- fix device orientation issues with TOMSSuggestionBar *
//- add help tip "backspace to delete" in keyb accessory view when selecting token *
//- build suggestion keyword list during metadata sync (fectch all titles in an array)
//- add any new keyword to local DB for suggestion until next sync (sync will wipe local keywords not yet uploaded) not implemented for creator and contributor

- (BOOL)tokenFieldShouldReturn:(JSTokenField *)tokenField
{
    if (![tokenField.textField.text length])
    {
        //dismiss keyboard
        [tokenField.textField resignFirstResponder];
        return NO;
    }
    
    NSString *tokenId = [self getTokenIdForString:[tokenField.textField text]];
    
    if ([tokenField.textField text] && [tokenId length])
    {
        [tokenField addTokenWithTitle:[tokenField.textField text] representedObject:tokenId];
    }
    
    [[tokenField textField] setText:@""];
    
    if (tokenField.bounds.size.height > kTokenFieldTableRowMaxHeight - tokenField.textField.bounds.size.height)
    {
        [tokenField.textField resignFirstResponder];
    }
    
    return NO;
}

- (void)tokenField:(JSTokenField *)tokenField didAddToken:(NSString *)title representedObject:(id)obj
{
    NSDictionary *value = [NSDictionary dictionaryWithObject:obj forKey:title];
    
    if (tokenField == self.contributorTokenField)
    {
        [self.contributorTokens addObject:value];
        self.contributorString = [self buildFieldStringForTokens:self.contributorTokens];
        DLog(@"Added contributor token for < %@ : %@ >\n%@\nCurrent contributor string: %@", title, obj, self.contributorTokens, self.contributorString);
    }
    else if (tokenField == self.creatorTokenField)
    {
        [self.creatorTokens addObject:value];
        self.creatorString = [self buildFieldStringForTokens:self.creatorTokens];
        DLog(@"Added creator token for < %@ : %@ >\n%@\nCurrent creator string: %@", title, obj, self.creatorTokens, self.creatorString);
    }
    
}

- (void)tokenField:(JSTokenField *)tokenField didRemoveToken:(NSString *)title representedObject:(id)obj;
{
    if (tokenField == self.contributorTokenField)
    {
        [self.contributorTokens removeObject:[NSDictionary dictionaryWithObject:obj forKey:title]];
        self.contributorString = [self buildFieldStringForTokens:self.contributorTokens];
        DLog(@"Deleted contributor token %@\n%@\nCurrent contributor string: %@", title, self.contributorTokens, self.contributorString);
    }
    else if (tokenField == self.creatorTokenField)
    {
        [self.creatorTokens removeObject:[NSDictionary dictionaryWithObject:obj forKey:title]];
        self.creatorString = [self buildFieldStringForTokens:self.creatorTokens];
        DLog(@"Deleted creator token %@\n%@\nCurrent creator string: %@", title, self.creatorTokens, self.creatorString);
    }
}

- (NSString *)buildFieldStringForTokens:(NSArray *)tokens
{
    NSMutableString *fieldString = [NSMutableString string];
    
    //build a comma/semicolon separated list of all inserted tokens
    for (NSDictionary *token in tokens)
    {
        NSString *title = [[token allKeys] objectAtIndex:0];
        
        if ([MukurtuSession sharedSession].serverCMSVersion1)
        {
            [fieldString appendFormat:@"%@,", title];
        }
        else
        {
            [fieldString appendFormat:@"%@;", title];
        }
    }
    
    return [NSString stringWithString:fieldString];
}

- (void)tokenFieldDidEndEditing:(JSTokenField *)tokenField
{
    if ([[tokenField.textField text] length] > 1)
    {
        NSString *tokenId = [self getTokenIdForString:[tokenField.textField text]];
        
        [tokenField addTokenWithTitle:[tokenField.textField text] representedObject:tokenId];
        [tokenField.textField setText:nil];
    }
    
    if (tokenField.bounds.size.height > kTokenFieldTableRowMaxHeight - tokenField.textField.bounds.size.height)
    {
        [tokenField.textField resignFirstResponder];
    }
}

- (NSString *) getTokenIdForString:(NSString *)title
{
    NSMutableString *tokenId = [NSMutableString string];
    
    NSMutableCharacterSet *charSet = [[NSCharacterSet whitespaceCharacterSet] mutableCopy];
    [charSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    
    for (int i = 0; i < [title length]; i++)
    {
        if (![charSet characterIsMember:[title characterAtIndex:i]])
        {
            [tokenId appendFormat:@"%@",[NSString stringWithFormat:@"%c", [title characterAtIndex:i]]];
        }
    }
    
    return [NSString stringWithString:tokenId];
}

- (BOOL)tokenFieldShouldBeginEditing:(JSTokenField *)tokenField
{
    if (tokenField.bounds.size.height > kTokenFieldTableRowMaxHeight - tokenField.textField.bounds.size.height)
    {
        return NO;
    }
    
    return YES;
}


- (void)tokenFieldFrameChanged:(NSNotification *)notification
{
    DLog(@"TokenField frame changed %@", [notification description]);
    
    JSTokenField *tokenField = notification.object;
    BOOL wasEditing = [tokenField.textField isFirstResponder];
    
    //this will reload table rows height (with updated token fields height) _without_ dismissing keyboard
    //on the contrary, using tableView reloadRowsAtIndexPaths: or reloadSections: will dismiss keyboard automatically
    //http://stackoverflow.com/questions/5344206/change-uitableview-row-height-without-dismissing-keyboard
    [self.tableView beginUpdates]; // updates the row heights ...
    [self.tableView endUpdates]; // ... nothing needed in between
    
    if (!wasEditing)
    {
        //if frame changes when not editing, we are adding tokens programmatically when loading a poi
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    else
    {
        if (tokenField == self.contributorTokenField)
        {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kMukurtuSectionIndexContributor] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
        else if (tokenField == self.creatorTokenField)
        {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kMukurtuSectionIndexCreator] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }
    
}

@end
