//
//  OptMetadataTableViewController.m
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

#import "OptMetadataTableViewController.h"
#import "PSPDFTextView.h"
#import "IphoneCreatePoiOptionalViewController.h"

#import "Poi.h"
#import "PoiKeyword.h"
#import "MukurtuSession.h"

//FIX 2.5: added custom ui control to handle keywords
#import "JSTokenField.h"
#import "TOMSSuggestionBar.h"


#define kCharCounterTag 101
#define CHARCOUNTER(a) ((UILabel *) [[ a leftView] viewWithTag:101])

//#define kMukurtuOptionalMetadataGroupRowHeight 115.0
//#define kMukurtuMetadataTextViewHeight (kMukurtuOptionalMetadataGroupRowHeight - kMukurtuMetadataTextFieldPadding * 2)

#define kMukurtuOptionalMetadataNumberOfSections 3

#define kMukurtuOptionalSectionIndexKeywords 0
#define kMukurtuOptionalSectionIndexDescription 1
#define kMukurtuOptionalSectionIndexCulturalNarrative 2

#define kMukurtuTopBarHeight 58.0f



@interface OptMetadataTableViewController ()<UITextViewDelegate, JSTokenFieldDelegate, TOMSSuggestionDelegate>
{
    
    __weak UITextView *editingView;
    
    CGRect _keyboardRect;
    BOOL _keyboardVisible;
    CGFloat rowHeight;
    
    __weak IphoneCreatePoiOptionalViewController  *containerController;

}

//FIX 2.5: added custom ui control to handle keywords
@property (nonatomic, strong) NSMutableArray *keywordsTokens;
@property (nonatomic, strong) JSTokenField *keywordsTokenField;


@end

@implementation OptMetadataTableViewController

////Helpers
- (void) errorAlert:(NSString *) message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error!" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];
}

- (PSPDFTextView *) createMetadataTextView
{
    CGFloat textViewHeight = rowHeight - kMukurtuMetadataTextFieldPadding * 2;
    
    PSPDFTextView *textView = [[PSPDFTextView alloc] initWithFrame:CGRectMake(kMukurtuMetadataTextFieldPadding,
                                                                              kMukurtuMetadataTextFieldPadding,
                                                                              CGRectGetWidth(self.view.frame) - kMukurtuMetadataTextFieldPadding * 2,
                                                                              textViewHeight)];
    
    textView.layer.borderWidth = 1.0;
    textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    textView.layer.cornerRadius = 5.0;
    textView.layer.masksToBounds = YES;
    
    //textView.contentInset = UIEdgeInsetsMake(0.0, 3, 3, 3);
    textView.autocorrectionType = UITextAutocorrectionTypeYes;
    textView.keyboardType = UIKeyboardTypeASCIICapable;
    textView.returnKeyType = UIReturnKeyDefault;
    textView.font = [UIFont systemFontOfSize:kMukurtuMetadataFontSize];
    
    textView.delegate = self;
    
    return textView;
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
    DLog(@"Optional Metadata did load");
    
    [super viewDidLoad];
    
    //save reference to container
    containerController = (IphoneCreatePoiOptionalViewController*) self.parentViewController;
    
    //FIX 2.5: added custom ui control to handle tokens for contributor and creator
    //contributor
    self.keywordsTokens = [NSMutableArray array];
    self.keywordsTokenField = [[JSTokenField alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 31)];
    [self.keywordsTokenField setDelegate:self];
    
    
    // Register notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    DLog(@"current row height %f view frame: %@", rowHeight, NSStringFromCGRect(self.view.frame));
    rowHeight = (CGRectGetHeight(self.view.frame) - (kMukurtuSectionHeaderHeight * kMukurtuOptionalMetadataNumberOfSections) - kMukurtuTopBarHeight) / kMukurtuOptionalMetadataNumberOfSections;
    
    //init description text view
    PSPDFTextView *descTextView = [self createMetadataTextView];
    //[descTextView setText:self.description];
    [descTextView setText:self.poiDescription];
    descTextView.tag = kMukurtuOptionalSectionIndexDescription;
    descTextView.delegate = self;
    self.descriptionTextView = descTextView;
    
    
      //init cultural narrative text view
    PSPDFTextView *cultTextView = [self createMetadataTextView];
    [cultTextView setText:self.culturalNarrative];
    cultTextView.tag = kMukurtuOptionalSectionIndexCulturalNarrative;
    cultTextView.delegate = self;
    self.culturalNarrativeTextView = cultTextView;

    
//    //init keywords text view
//    PSPDFTextView *keywordsTextView = [self createMetadataTextView];
//    
//    //disable autocorrection just for keywords (annoying)
//    keywordsTextView.autocorrectionType = UITextAutocorrectionTypeNo;
//    keywordsTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
//    
//    [keywordsTextView setText:self.keywords];
//    keywordsTextView.tag = kMukurtuOptionalSectionIndexKeywords;
//    keywordsTextView.delegate = self;
//    self.keywordsTextView = keywordsTextView;
    
    //if (self.parentContainer.tempPoi != nil)
    //    [self loadOptionaMetadataFromPoi:containerController.tempPoi];

}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.keywordsTokenField updateBarFrame];
    
    //FIX 2.5: keywords uses token field, rebuild tokens
    if ([self.keywords length])
    {
        NSArray *keywordsList;
        
        if ([MukurtuSession sharedSession].serverCMSVersion1)
        {
            keywordsList = [self.keywords componentsSeparatedByString:@","];
        }
        else
        {
            keywordsList = [self.keywords componentsSeparatedByString:@";"];
        }
        
        for (NSString *keyword in keywordsList)
        {
            if ([keyword length])
            {
                NSString *tokenId = [self getTokenIdForString:keyword];
                [self.keywordsTokenField addTokenWithTitle:keyword representedObject:tokenId];
            }
        }
    }
    
    [self.tableView reloadData];
    
    
    //add contributor suggestions bar
    TOMSSuggestionBar *suggestionBar = [[TOMSSuggestionBar alloc] initWithNumberOfSuggestionFields:2];
    [suggestionBar subscribeTextInputView:self.keywordsTokenField.textField
           toSuggestionsForAttributeNamed:@"name"
                            ofEntityNamed:@"PoiKeyword"
                             inModelNamed:@"Mukurtu2"];
    suggestionBar.font = [UIFont systemFontOfSize:16];
    suggestionBar.delegate = self;
    
}


- (void) loadOptionaMetadataFromPoi:(Poi *)poi
{
    DLog(@"Loading optional metadata from pooi");
    
    self.poiDescription = [poi.longdescription copy];
    self.culturalNarrative = [poi.culturalNarrative copy];
    self.keywords = [poi.keywordsString copy];
    
    
    //DLog(@"poi metadata texts: \n%@\n%@\n%@", poi.longdescription, poi.culturalNarrative, poi.keywordsString);
    //DLog(@"texview fields: \n%@\n%@\n%@", self.description, self.culturalNarrative, self.keywords);

}

//- (void)dealloc {
//    [NSNotificationCenter.defaultCenter removeObserver:self];
//}

- (void) viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


////Keyboard Notifications
#pragma mark - Keyboard Notifications

- (void)keyboardWillShowNotification:(NSNotification *)notification {
    if (!_keyboardVisible) {
        _keyboardVisible = YES;
        _keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        [(PSPDFTextView *)editingView scrollToVisibleCaretAnimated:NO]; // Animating here won't bring us to the correct position.
        [self updateControlsToFitKeyboard];
    }
}

- (void)keyboardWillHideNotification:(NSNotification *)notification {
    if (_keyboardVisible) {
        _keyboardVisible = NO;
        _keyboardRect = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
        [self updateControlsToFitKeyboard];
    }
}

- (void) updateControlsToFitKeyboard
{
    //[self.view layoutIfNeeded]; // Ensures that all pending layout operations have been completed
    
    if (_keyboardVisible)
    {
    
    }
    else
    {
        [(PSPDFTextView *)editingView scrollRangeToVisible:NSRangeFromString(@"")];
    }
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return  kMukurtuOptionalMetadataNumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger numRows;
    
    switch (section)
    {
        case kMukurtuOptionalSectionIndexKeywords:
            numRows = 1;
            break;
            
        case kMukurtuOptionalSectionIndexDescription:
            numRows = 1;
            break;
            
        case kMukurtuOptionalSectionIndexCulturalNarrative:
            numRows = 1;
            break;
            
        default:
            numRows = 0;
            break;
    }
    
    return numRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifierKeywords = @"MetadataCellKeywords";
    static NSString *CellIdentifierTextView = @"MetadataCellTextView";
    
    
    UITableViewCell *cell;
    NSString *cellIdentifier;
    
    if ([indexPath section] == kMukurtuOptionalSectionIndexKeywords)
        cellIdentifier = CellIdentifierKeywords;
    else
        if ([indexPath section] == kMukurtuOptionalSectionIndexDescription ||
            [indexPath section] == kMukurtuOptionalSectionIndexCulturalNarrative)
            cellIdentifier = CellIdentifierTextView;
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
    
    
    switch ([indexPath section])
    {
        case kMukurtuOptionalSectionIndexKeywords:
            //[cell.contentView addSubview:self.keywordsTextView];
        {
            [cell.contentView addSubview:self.keywordsTokenField];
            
            SEL selectorKeywordViewTap = NSSelectorFromString(@"keywordViewTap:");
            [cell.contentView setUserInteractionEnabled:YES];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selectorKeywordViewTap];
            [tap setNumberOfTapsRequired:1];
            [cell.contentView setGestureRecognizers:[NSArray arrayWithObject:tap]];
        }
            break;
            
        case kMukurtuOptionalSectionIndexDescription:
            [cell.contentView addSubview:self.descriptionTextView];
            break;
            
        case kMukurtuOptionalSectionIndexCulturalNarrative:
            [cell.contentView addSubview:self.culturalNarrativeTextView];
            break;
            
        default:
            break;
    }
    
    
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    switch ([indexPath section])
    {
        default:
            //DLog(@"current row height %f view frame: %@", rowHeight, NSStringFromCGRect(self.view.frame));
            return rowHeight;
            break;
    }
    
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    switch ([indexPath section])
    {
        default:
            break;
    }
    
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    
    NSString *sectionTitle;
    
    // Return the number of rows in the section.
    switch (section)
    {
        case kMukurtuOptionalSectionIndexDescription:
            //description
            sectionTitle = @"DESCRIPTION";
            break;
            
        case kMukurtuOptionalSectionIndexCulturalNarrative:
            //cultural narrative
            sectionTitle = @"CULTURAL NARRATIVE";
            break;
            
        case kMukurtuOptionalSectionIndexKeywords:
            //description
            sectionTitle = @"KEYWORDS";
            break;
            
        default:
            sectionTitle = @"";
            break;
    }
    
    
    // create the parent view that will hold header Label
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.frame), kMukurtuSectionHeaderHeight)];
    customView.backgroundColor = kUIColorOrange;
    
    // create the button object
    UIButton *btnHeader = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnHeader addTarget:self action:@selector(sectionHelpPressed:) forControlEvents:UIControlEventTouchUpInside];
    btnHeader.tag = section;
    
    UIImage *btnHeaderImage = [UIImage imageNamed:@"sectionInfoIcon.png"];
    [btnHeader setBackgroundImage:btnHeaderImage forState:UIControlStateNormal];
    [btnHeader setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    CGFloat padding = (kMukurtuSectionHeaderHeight - btnHeaderImage.size.height)/2;
    btnHeader.frame = CGRectMake((CGRectGetWidth(self.view.frame) - btnHeaderImage.size.width - padding) ,
                                 padding,
                                 btnHeaderImage.size.width,
                                 btnHeaderImage.size.height);
    [customView addSubview:btnHeader];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    [titleLabel setText:sectionTitle];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.opaque = NO;
    titleLabel.frame = CGRectMake(2.0, 0.0, CGRectGetWidth(self.view.frame), kMukurtuSectionHeaderHeight);
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
        case kMukurtuOptionalSectionIndexKeywords:
            //keywords
            helpMessage = @"Add keywords associated with this item.\nKeywords make it easier to browse and discover your stories.\nUse \"Return\" to add a new keyword.";
            break;
            
        case kMukurtuOptionalSectionIndexDescription:
            //description
            helpMessage = @"Use this field to add a description of this item.\nInclude physical characteristics (examples: photograph (lantern slide); manuscript; typescript; newspaper clipping) and content information (for an image, what is depicted; for a text item, what is it about); also give additional date information or other relevant details.\nAnything that describes the scene, event, subject. The more the better!\nYou can always edit it later on your Mukurtu site.";
            break;
            
        case kMukurtuOptionalSectionIndexCulturalNarrative:
            //cultural narrative
            //helpMessage = @"Use this field to provide general cultural context and background information for the content.";
            helpMessage = @"You can use this field to provide general cultural context or historical background information for the content.";
            break;
            
        default:
            helpMessage = @"";
            break;
    }
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Help" message:helpMessage delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];
    
}


#pragma mark - Text View Delegate methods
- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    return YES;
}


- (void)textViewDidBeginEditing:(UITextView *)textView

{
    DLog(@"text view begin edit");
    
    [self.parentContainer childControllerBeginEdit];
    
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:textView.tag]
                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
    
    editingView = textView;
}

- (void)textViewDidEndEditing:(UITextView *)textView

{
    DLog(@"text view edit ended");
    
    [textView resignFirstResponder];
    editingView = nil;
    
}

- (void)editDoneButtonPressed
{
    DLog(@"Edit Done Button pressed on parent Container");
    [editingView resignFirstResponder];
}


//FIX 2.5: added custom ui control to handle keywords
#pragma mark - TOMSSuggestionDelegate

- (void)suggestionBar:(TOMSSuggestionBar *)suggestionBar
  didSelectSuggestion:(NSString *)suggestion
     associatedObject:(NSManagedObject *)associatedObject
{
    JSTokenField *tokenField;
    
    if ([associatedObject isKindOfClass:[PoiKeyword class]])
    {
        tokenField = self.keywordsTokenField;
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
    
    if (tokenField.bounds.size.height > rowHeight - tokenField.textField.bounds.size.height)
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
    
    if (tokenField.bounds.size.height > rowHeight - tokenField.textField.bounds.size.height)
    {
        [tokenField.textField resignFirstResponder];
    }
    
    return NO;
}

- (void)tokenField:(JSTokenField *)tokenField didAddToken:(NSString *)title representedObject:(id)obj
{
    NSDictionary *value = [NSDictionary dictionaryWithObject:obj forKey:title];
    
    if (tokenField == self.keywordsTokenField)
    {
        [self.keywordsTokens addObject:value];
        self.keywords = [self buildFieldStringForTokens:self.keywordsTokens];
        DLog(@"Added keyword token for < %@ : %@ >\n%@\nCurrent keyword string: %@", title, obj, self.keywordsTokens, self.keywords);
    }
}

- (void)tokenField:(JSTokenField *)tokenField didRemoveToken:(NSString *)title representedObject:(id)obj;
{
    if (tokenField == self.keywordsTokenField)
    {
        [self.keywordsTokens removeObject:[NSDictionary dictionaryWithObject:obj forKey:title]];
        self.keywords = [self buildFieldStringForTokens:self.keywordsTokens];
        DLog(@"Deleted keyword token %@\n%@\nCurrent keyword string: %@", title, self.keywordsTokens, self.keywords);
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
    
    if (tokenField.bounds.size.height > rowHeight - tokenField.textField.bounds.size.height)
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
    if (tokenField.bounds.size.height > rowHeight - tokenField.textField.bounds.size.height)
    {
        return NO;
    }
    
    return YES;
}

- (void) keywordViewTap:(UITapGestureRecognizer *)tap
{
    DLog(@"Tapped keyword BG, force tokenfield focus");
    [self.keywordsTokenField.textField becomeFirstResponder];
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kMukurtuOptionalSectionIndexKeywords]
                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

//- (void)tokenFieldFrameChanged:(NSNotification *)notification
//{
//    DLog(@"TokenField frame changed %@", [notification description]);
//    
//    JSTokenField *tokenField = notification.object;
//    BOOL wasEditing = [tokenField.textField isFirstResponder];
//    
//    //this will reload table rows height (with updated token fields height) _without_ dismissing keyboard
//    //on the contrary, using tableView reloadRowsAtIndexPaths: or reloadSections: will dismiss keyboard automatically
//    //http://stackoverflow.com/questions/5344206/change-uitableview-row-height-without-dismissing-keyboard
//    [self.tableView beginUpdates]; // updates the row heights ...
//    [self.tableView endUpdates]; // ... nothing needed in between
//    
//    if (!wasEditing)
//    {
//        //if frame changes when not editing, we are adding tokens programmatically when loading a poi
//        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
//    }
//    else
//    {
//        if (tokenField == self.keywordsTokenField)
//        {
//            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kMukurtuOptionalSectionIndexKeywords] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
//        }
//    }
//}



@end
