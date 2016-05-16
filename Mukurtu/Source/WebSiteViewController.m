//
//  WebSiteViewController.m
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

#import "WebSiteViewController.h"

#import "MukurtuSession.h"

@interface WebSiteViewController ()<UIWebViewDelegate>
{
    BOOL loading;
}

@property (nonatomic) IBOutlet UIButton *webBackButton;
@property (nonatomic) IBOutlet UIButton *webForwardButton;
@property (nonatomic, strong) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UILabel *baseUrlLabel;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;

@end


@implementation WebSiteViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    loading = NO;
    
    NSString *baseUrl = [[MukurtuSession sharedSession] storedBaseUrl];
    
    NSString *baseBrowseUrl;
    
    if ([[MukurtuSession sharedSession] serverCMSVersion1])
    {
        baseBrowseUrl = [NSString stringWithFormat:@"%@/browse", baseUrl];
    }
    else
    {
        baseBrowseUrl = [NSString stringWithFormat:@"%@/digital-heritage", baseUrl];
    }
    
    [self.baseUrlLabel setText:baseUrl];
    
    DLog(@"Start Loading URL %@", baseBrowseUrl);
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:baseBrowseUrl]]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (IBAction)backPressed:(id)sender
{
    [WebSiteViewController cancelPreviousPerformRequestsWithTarget:self];

    [self dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)goBack:(id)sender
{
    if (self.webView.canGoBack)
        [self.webView goBack];
}

- (IBAction)goForward:(id)sender
{
    if (self.webView.canGoForward)
        [self.webView goForward];
}

- (IBAction)reloadWebView:(id)sender
{
    [self.activityIndicator startAnimating];
    self.activityIndicator.hidden = NO;
    
    [self.webView reload];
}

- (void) webViewDidStartLoad:(UIWebView *)webView
{
    DLog(@"Start loading page");
    if (!loading)
    {
        loading = YES;
        
        [self.activityIndicator startAnimating];
        self.activityIndicator.hidden = NO;

        DLog(@"Starting timeout timer for reload on error");
        [self performSelector:@selector(timeoutLoading) withObject:nil afterDelay:60.0];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    DLog(@"Error loading page");
    
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    
    [WebSiteViewController cancelPreviousPerformRequestsWithTarget:self];
    
    //alert user
    DLog(@"web  view page load failed, Base URL is not reachable?");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                    message:@"This Mukurtu site is not reachable now. Check the URL you provided and your Internet connection and retry"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    DLog(@"webView finished loading");
    [WebSiteViewController cancelPreviousPerformRequestsWithTarget:self];
    
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    
    if (!self.webView.canGoBack)
        self.webBackButton.enabled = NO;
    else
        self.webBackButton.enabled = YES;
    
    if (!self.webView.canGoForward)
        self.webForwardButton.enabled = NO;
    else
        self.webForwardButton.enabled = YES;
}

- (void) timeoutLoading
{
    DLog(@"Timeout called on webview");
    
    loading = NO;
    
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    
    [WebSiteViewController cancelPreviousPerformRequestsWithTarget:self];
    
    //alert user
    DLog(@"web  view page load failed, Base URL is not reachable?");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                    message:@"This Mukurtu site is not reachable now. Check the URL you provided and your Internet connection and retry"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

@end
