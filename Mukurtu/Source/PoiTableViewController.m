//
//  PoiTableViewController.m
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

#import "PoiTableViewController.h"

#import "Poi.h"
#import "PoiCell.h"
#import "PoiMedia.h"
#import "ImageSaver.h"

#import "MukurtuSession.h"

@interface PoiTableViewController ()

//@property  (strong,nonatomic) NSMutableArray *poiList;

@end



@implementation PoiTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self fetchAllPois];
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)fetchAllPois
{
    self.poiList = [[Poi MR_findAllSortedBy:@"timestamp" ascending:NO] mutableCopy];
}

#pragma mark - Table view data source

- (void)configureCell:(UITableViewCell*)cell atIndex:(NSIndexPath*)indexPath
{
    PoiCell *customCell = (PoiCell *) cell;
    
    Poi *poi = self.poiList[indexPath.row];
    customCell.titleLabel.text = [poi.title copy];
    customCell.creationDateLabel.text = [NSDateFormatter localizedStringFromDate:poi.timestamp
                                                                       dateStyle:NSDateFormatterLongStyle
                                                                       timeStyle:NSDateFormatterNoStyle];
    
    if ([poi.media count])
    {
        NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
        NSArray *orderedPoiMedias = [poi.media sortedArrayUsingDescriptors:sortDescriptors];
        
        PoiMedia *media = orderedPoiMedias[0];
        //[customCell.thumbImage setImage:[UIImage imageWithContentsOfFile:media.thumbnail]];
        [customCell.thumbImage setImage:[UIImage imageWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:media.thumbnail]]];
        
    }
    else
        [customCell.thumbImage setImage:[UIImage imageNamed:@"background_thumbnail"]];
    
    //show alert if poi has errors
    if ([poi.key length] > 0)
    {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"alert_arancio.png"]];
        
        cell.accessoryView = imageView;
    }
    else
    {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"next_grigio.png"]];
        
        cell.accessoryView = imageView;
    }
    
    //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
   
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.poiList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"PoiCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndex:indexPath];

    
    return cell;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setBackgroundColor:kUIColorLightGrayBackground];

}

- (void)reloadData
{
    DLog(@"poi list reload data");
    
   
    
    [self fetchAllPois];
    
    [self.tableView reloadData];
    
#warning could animate insertion (need new poi parameter to find row position to animate)
    /*
    [self.tableView beginUpdates];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
     */
    
}

- (void) showUploadResult
{
    DLog(@"Checking upload results and report with alert");
    
    NSString *message;
    NSString *title;
    
    if (![self.poiList count])
    {
        DLog(@"Success: all poi uploaded");
        message = kUploadAllPoiSuccess;
        title = @"Upload complete";
        
        //check demo user and change message
        if ([[MukurtuSession sharedSession] isUsingDemoUser])
            message = kUploadAllPoiSuccessDemo;
    }
    else
    {
#warning should make difference from total failed upload and partial upload fail
        DLog(@"Failure: some poi (or all ones) could not be uploaded");
        message = kUploadAllPoiFailure;
        title = @"Warning!";
        
    }
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];

    
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
#warning should show error message (after validation) if present
    //if ([managedObject valueForKey:@"key"] != nil && [[managedObject valueForKey:@"key"] length] > 0)
    //    [self errorAlert:[NSString stringWithFormat:@"%@", [managedObject valueForKey:@"key"]]];
    
    Poi *poi = [self.poiList objectAtIndex:[indexPath row]];
    
    DLog(@"Row tapped, ask main controller to edit poi %@", poi.title);
    
    SEL selectorEditPoi = NSSelectorFromString(@"editPoi:");
    if ([self.mainViewController respondsToSelector:selectorEditPoi])
    {
        //[self.mainViewController performSelector:selectorEditPoi withObject:poi];
        SuppressPerformSelectorLeakWarning([self.mainViewController performSelector:selectorEditPoi withObject:poi]);
    }
        
    
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // Delete the row from the data source
        Poi *poi = [self.poiList objectAtIndex:[indexPath row]];
        
        DLog(@"removing %d media and files for poi %@ from store", (int)[poi.media count], poi.title);
        for (PoiMedia *media in [poi.media allObjects])
        {
            [ImageSaver deleteMedia:media];
        }
        
        DLog(@"removing poi %@ from store", poi.title);
        [poi MR_deleteEntity];
        
        [self.poiList removeObjectAtIndex:[indexPath row]];
        
        DLog(@"removing row %d", (int)[indexPath row]);
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        

        DLog(@"Saving context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        
        SEL selectorUpdateMainMap = NSSelectorFromString(@"updateMainMap");
        if ([self.mainViewController respondsToSelector:selectorUpdateMainMap])
        {
            //[self.mainViewController performSelector:selectorEditPoi withObject:poi];
            SuppressPerformSelectorLeakWarning([self.mainViewController performSelector:selectorUpdateMainMap]);
        }
        
        /*
        [[NSManagedObjectContext defaultContext] saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error) {
            if (success)
                DLog(@"Context saved");
            else
                DLog(@"Context save failure! error: %@", [error description]);
        }];*/
        
        
    }
    
    /*
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    } */
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


@end
