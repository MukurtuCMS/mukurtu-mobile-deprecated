//  ImageSaver.m
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

#import "ImageSaver.h"
#import "PoiMedia.h"
#import "UIImage+Resize.h"
#import "NSMutableDictionary+ImageMetadata.h"


#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>

//#define kMediaPhotoJPGCompression 0.7
#define kMediaPhotoJPGCompression 0.85

#define kMukurtuAudioFileBackupPrefix @"AUDIOBAK"

@implementation ImageSaver


+ (NSString *) findUniquePicBasename:(NSString *)prefix
{
	int i = 0;
	NSString *path;
    NSString *thumb;
    NSString *video;
    NSString *audio;
    NSString *uniqueId = [[NSUUID UUID] UUIDString];
    
    if (prefix == nil)
        prefix = @"";
    
    NSString *filteredPrefix = [[prefix componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    //NSInteger  timestamp = (NSInteger) [[NSDate date] timeIntervalSince1970];
	do {
		// iterate until a name does not match an existing file
        i++;
        //path = [NSString stringWithFormat:@"%@/Documents/%ld_%03d_pic.jpg", NSHomeDirectory(), (long)timestamp, i];
        //thumb = [NSString stringWithFormat:@"%@/Documents/%ld_%03d_thumb.jpg", NSHomeDirectory(), (long)timestamp, i];
        
        path = [NSString stringWithFormat:@"Documents/%@_%@_pic.jpg", filteredPrefix, uniqueId];
        thumb = [NSString stringWithFormat:@"Documents/%@_%@_thumb.jpg", filteredPrefix, uniqueId];
        video = [NSString stringWithFormat:@"Documents/%@_%@_video.mp4", filteredPrefix, uniqueId];
        audio = [NSString stringWithFormat:@"Documents/%@_%@_audio.m4a", filteredPrefix, uniqueId];
        //audio = [NSString stringWithFormat:@"Documents/%@_%@_audio.mp4", filteredPrefix, uniqueId];
	} while (([[NSFileManager defaultManager] fileExistsAtPath:path]) ||
             ([[NSFileManager defaultManager] fileExistsAtPath:thumb])||
             ([[NSFileManager defaultManager] fileExistsAtPath:video])||
             ([[NSFileManager defaultManager] fileExistsAtPath:audio]));
	
	return [NSString stringWithFormat:@"Documents/%@_%@", filteredPrefix, uniqueId];
}



+ (PoiMedia *) saveImageToDisk:(UIImage *)image withExifMetadata:(NSDictionary *)metadata andCreateMediawithNamePrefix:(NSString *)prefix
{
    DLog(@"Saving image to disk with exif metadata and creating media");
    
     PoiMedia *newMedia = nil;
    
    //resize image here and set filename with postfix (init with default full res, setted later by prefs)
    NSString *resizePostfix = kMukurtuResizedImagePostfixFull;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults objectForKey:kPrefsMukurtuResizeImagesKey])
    {
        resizePostfix = [defaults objectForKey:kPrefsMukurtuResizeImagesKey];
        DLog(@"Reading image resize factor from preferences, postfix: %@", resizePostfix);

    }
    else
    {
        //default key for resize factor tag should be present, anyway defaults to full res

        DLog(@"Preferences key for image resize factor not present (firs run?), defaults to full res");
        resizePostfix = kMukurtuResizedImagePostfixFull;
        
        DLog(@"Default image resize factor, postfix: %@", resizePostfix);
    }
    
    
    if ([resizePostfix isEqualToString:kMukurtuResizedImagePostfixFull])
    {
        //do nothing, image is already full res
        DLog(@"Leaving image full res without resizing");
    }
    else
    {
        //we need to resize image according to prefs, choose resize factor
        
        CGSize newSize;
        if ([resizePostfix isEqualToString:kMukurtuResizedImagePostfixLarge])
        {
            //resize image to 75%
            newSize = CGSizeMake(image.size.width * 0.75, image.size.height * 0.75);
        }
        else
            if ([resizePostfix isEqualToString:kMukurtuResizedImagePostfixMedium])
            {
                //resize image to 50%
                newSize = CGSizeMake(image.size.width * 0.50, image.size.height * 0.50);
            }
            else
                if ([resizePostfix isEqualToString:kMukurtuResizedImagePostfixSmall])
                {
                    //resize image to 25%
                    newSize = CGSizeMake(image.size.width * 0.25, image.size.height * 0.25);
                }
                else
                    if ([resizePostfix isEqualToString:kMukurtuResizedImagePostfixWeb])
                    {
                        //resize image to 1024x768

                        //FIX 2.5: check portrait or landscape form factor
                        if (image.size.width > image.size.height)
                        {
                            //landscape
                            newSize = CGSizeMake(1024, 768);
                        }
                        else
                        {
                            //portrait
                            newSize = CGSizeMake(768, 1024);
                        }
                    }
                    else
                    {
                        //just for safe coding, defaults to full res in case of errors
                        newSize = CGSizeMake(image.size.width, image.size.height);
                    }
        
        DLog(@"Resize image to %@, original size: %@, new size: %@", resizePostfix, NSStringFromCGSize(image.size), NSStringFromCGSize(newSize));
        
        image = [image resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:newSize interpolationQuality:kCGInterpolationHigh];
    }
    
    
    UIImage *thumbnail = [image thumbnailImage:128 transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationHigh];
    NSData *imgThumbData   = UIImageJPEGRepresentation(thumbnail, 0.8);
    
    
    NSString *name    = [ImageSaver findUniquePicBasename:prefix];
    
    NSString *filepath	= [NSString stringWithFormat:@"%@_pic%@.jpg", name, resizePostfix];
    NSString *thumbpath = [NSString stringWithFormat:@"%@_thumb.jpg", name];
    
    NSString *jpgPath = [NSHomeDirectory() stringByAppendingPathComponent:filepath];
    NSString *pngThumbPath = [NSHomeDirectory() stringByAppendingPathComponent:thumbpath];
    
    NSTimeInterval originalTimestamp = -1;
    
    if (metadata)
    {
        NSDictionary *exifDic = [metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary];
        if (exifDic)
        {
            DLog(@"Storing original date from exif metadata if present");
            
            NSString *originalDateString = [exifDic objectForKey:(NSString*)kCGImagePropertyExifDateTimeDigitized];
            
            DLog(@"original Date string %@", originalDateString);
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
            [dateFormatter setTimeZone:timeZone];
            [dateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
            
            NSDate *originalDate = [dateFormatter dateFromString:originalDateString];
            
            DLog(@"Obtained UTC date %@", [originalDate description]);
            
            originalTimestamp = [originalDate timeIntervalSince1970];
            
            DLog(@"Obtained original timestamp  %d", (int32_t) originalTimestamp);
        }
    }
    
    
    // Set your compression quuality (0.0 to 1.0).
    NSMutableDictionary *mutableMetadata = [metadata mutableCopy];
    
#warning image compression could be a preferences key not an hardcoded macro
    //[mutableMetadata setObject:@(1.0) forKey:(__bridge NSString *)kCGImageDestinationLossyCompressionQuality];
    [mutableMetadata setObject:@(kMediaPhotoJPGCompression) forKey:(__bridge NSString *)kCGImageDestinationLossyCompressionQuality];
    
    // Create an image destination.
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:jpgPath], kUTTypeJPEG , 1, NULL);
    if (imageDestination == NULL ) {
        
        // Handle failure.
        DLog(@"Error -> failed to create image destination.");
        
        DLog(@"saving image file %@ failed", filepath);
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:@"There was an error saving your photo. Try again."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        
        return nil;
    }
    
    // Add your image to the destination.
    CGImageDestinationAddImage(imageDestination, image.CGImage, (__bridge CFDictionaryRef)mutableMetadata);
    
    // Finalize the destination.
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        
        // Handle failure.
        DLog(@"Error -> failed to finalize the image.");
        
        DLog(@"saving image file %@ failed", filepath);
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:@"There was an error saving your photo. Try again."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        
        return nil;
    }
    
    CFRelease(imageDestination);
    
    ///if we arrive here we have already saved a valid destination jpeg with metadata
    
    if ([imgThumbData writeToFile:pngThumbPath atomically:YES])
    {
        DLog(@"Image file saved with success to %@ thumb: %@", filepath, thumbpath);
        
        //should create update media object fields here
        newMedia = [PoiMedia MR_createEntity];
        newMedia.timestamp = [NSDate date];
        newMedia.type = @"photo";
        
        //FIX 2.5: store image path relative to home directory!
        newMedia.path = filepath;
        newMedia.thumbnail = thumbpath;
        
        //store original date as int32 (dirty hack)
        if (originalTimestamp > 0)
            newMedia.expectedSize = [NSNumber numberWithDouble:originalTimestamp];
        else
            newMedia.expectedSize = nil;
        
#ifdef DEBUG
        // DEBUG Show the current contents of the documents folder
        CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif
        
    }
    else
    {
        DLog(@"saving image file %@ failed", filepath);
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:@"There was an error saving your photo. Try again."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        
#ifdef DEBUG
        // DEBUG Show the current contents of the documents folder
        CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif
        
        newMedia = nil;
    }
     
     return newMedia;
     
}

//+ (BOOL)saveImageToDisk:(UIImage*)image andToMedia:(PoiMedia*)media withNamePrefix:(NSString *)prefix
+ (PoiMedia *) saveImageToDisk:(UIImage *)image andCreateMediawithNamePrefix:(NSString *)prefix
{
    
    PoiMedia *newMedia = nil;
    
    newMedia = [self saveImageToDisk:image withExifMetadata:nil andCreateMediawithNamePrefix:prefix];
    
    return  newMedia;
    
}


+ (PoiMedia *) saveAudioToDisk:(NSString *)tempAudioFilePath andCreateMediawithNamePrefix:(NSString *)prefix
{
    DLog(@"Saving audio to disk and creating media");
    NSError *error = nil;
    
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:tempAudioFilePath])
    {
        DLog(@"Temp audio file does not exists, failed creating media");
        return nil;
    }
    
    PoiMedia *newMedia = nil;
    
	NSString *name    = [ImageSaver findUniquePicBasename:prefix];

    
    //FIX 2.5: create a copy of mic icon in documents directory (just once) to use relative path for thumbnail.
    //abs path are not allowed in ios8
    NSString *filepath	= [NSString stringWithFormat:@"%@_audio.m4a", name];
    //NSString *filepath	= [NSString stringWithFormat:@"%@_audio.mp4", name];
    
    if (![manager fileExistsAtPath:[NSHomeDirectory() stringByAppendingPathComponent:kMicThumbIconPath]])
    {
        //create icon if not exists
        NSString *thumbSourcePath = [[NSBundle mainBundle] pathForResource:@"mic_gray-border" ofType:@"png"];
        [manager copyItemAtPath:thumbSourcePath toPath:[NSHomeDirectory() stringByAppendingPathComponent:kMicThumbIconPath] error:&error];
    }
    
    NSString *thumbpath = kMicThumbIconPath;
    
    //move recorder temp file to new pathname
    if ([manager moveItemAtPath:tempAudioFilePath toPath:[NSHomeDirectory() stringByAppendingPathComponent:filepath] error:&error])
    {
        DLog(@"Succesfully moved tempAudioFile %@ to new audio file %@", tempAudioFilePath, filepath);
    }
    else
    {
        DLog(@"Failed renaming of tempAudioFile %@ to new audio file %@ with error %@, cancel media creation", tempAudioFilePath, filepath, [error description]);
        return nil;
    }
    
    DLog(@"Creating new audio media %@", [filepath lastPathComponent]);
    
    //should create update media object fields here
    newMedia = [PoiMedia MR_createEntity];
    newMedia.timestamp = [NSDate date];
    newMedia.type = @"audio";
    newMedia.path = filepath;
    newMedia.thumbnail = thumbpath;
    
#ifdef DEBUG
        // DEBUG Show the current contents of the documents folder
        CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif
    
	return newMedia;
}



+ (PoiMedia *) saveVideoToDisk:(NSData *)videoData andCreateMediawithNamePrefix:(NSString *)prefix
{
    DLog(@"Saving video to disk and creating media");
    
    PoiMedia *newMedia = nil;
    
    NSString *name  = [ImageSaver findUniquePicBasename:prefix];
    
    NSString *filepath	= [NSString stringWithFormat:@"%@_video.mp4", name];
    NSString *thumbpath = [NSString stringWithFormat:@"%@_thumb.jpg", name];
    NSString *bigthumbpath = [NSString stringWithFormat:@"%@_thumb_big.jpg", name];
    
    NSString *fileFullPath = [NSHomeDirectory() stringByAppendingPathComponent:filepath];
    NSString *thumbFullPath = [NSHomeDirectory() stringByAppendingPathComponent:thumbpath];
    NSString *bigThumbFullPath = [NSHomeDirectory() stringByAppendingPathComponent:bigthumbpath];
    
    if (![videoData writeToFile:fileFullPath atomically:NO])
    {
        DLog(@"Fatal Error while writing video file %@ to disk, quit without creating media", fileFullPath);
        return nil;
    }
    else
        DLog(@"Video file %@ saved with success", [filepath lastPathComponent]);
        
    
    UIImage *bigThumbImage = [ImageSaver createVideoThumbnailFromFile:fileFullPath];
    
    
    //UIImage *watermarkImage = [UIImage imageNamed:@"video-play-icon.png"];
    UIImage *watermarkImage = [UIImage imageNamed:@"video-play-256.png"];
    
    UIGraphicsBeginImageContext(bigThumbImage.size);
    [bigThumbImage drawInRect:CGRectMake(0, 0, bigThumbImage.size.width, bigThumbImage.size.height)];
    [watermarkImage drawInRect:CGRectMake(bigThumbImage.size.width/2 - watermarkImage.size.width/2, bigThumbImage.size.height/2 - watermarkImage.size.height/2, watermarkImage.size.width, watermarkImage.size.height)];
    UIImage *bigThumbImageWatermark = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //NSData *imgBigThumbData  = UIImageJPEGRepresentation(bigThumbImage, kMediaPhotoJPGCompression);
    NSData *imgBigThumbData  = UIImageJPEGRepresentation(bigThumbImageWatermark, kMediaPhotoJPGCompression);
    
    //UIImage *thumbnail = [bigThumbImage thumbnailImage:128 transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationHigh];
    UIImage *backgroundImage = [bigThumbImage thumbnailImage:128 transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationHigh];
    
    UIImage *watermarkImageThumb = [UIImage imageNamed:@"icon_video_CROP.png"];
    
    UIGraphicsBeginImageContext(backgroundImage.size);
    [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    
    //bottom right placement
    //[watermarkImageThumb drawInRect:CGRectMake(backgroundImage.size.width - watermarkImageThumb.size.width*0.5, backgroundImage.size.height - watermarkImageThumb.size.height*0.5, watermarkImageThumb.size.width*0.5, watermarkImageThumb.size.height*0.5)];
    
    //center placement
#define kOffset 5
    [watermarkImageThumb drawInRect:CGRectMake(backgroundImage.size.width/2 + kOffset - watermarkImageThumb.size.width*0.25, backgroundImage.size.height/2 - watermarkImageThumb.size.height*0.25, watermarkImageThumb.size.width*0.5, watermarkImageThumb.size.height*0.5)];
    
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    NSData *imgThumbData = UIImageJPEGRepresentation(thumbnail, 0.8);
    
    //saving thumbnails
	if (([imgThumbData writeToFile:thumbFullPath atomically:NO]) &&
        ([imgBigThumbData writeToFile:bigThumbFullPath atomically:NO]))
    {
        DLog(@"Video is ok and Thumbnail files saved with success to small:%@ Bigthumb: %@", [thumbFullPath lastPathComponent], [bigThumbFullPath lastPathComponent]);
        
        //should create update media object fields here
        newMedia = [PoiMedia MR_createEntity];
        newMedia.timestamp = [NSDate date];
        newMedia.type = @"video";
        
        newMedia.path = filepath;
        newMedia.thumbnail = thumbpath;
        //newMedia.path = fileFullPath;
        //newMedia.thumbnail = thumbFullPath;
        
#ifdef DEBUG
        // DEBUG Show the current contents of the documents folder
        CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif
        
	}
    else
    {
        DLog(@"saving video file %@ failed", fileFullPath);
		[[[UIAlertView alloc] initWithTitle:@"Error"
									message:@"There was an error saving your video. Try again."
								   delegate:nil
						  cancelButtonTitle:@"OK"
						  otherButtonTitles: nil] show];
        
#ifdef DEBUG
        // DEBUG Show the current contents of the documents folder
        CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif
        
		newMedia = nil;
	}
    
	return newMedia;
}

+ (void) deleteMedia:(PoiMedia *)media
{
    DLog(@"Deleting Media %@ and related files", [media.path lastPathComponent]);
    
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    //if media is audio should keep a local copy
    if ([media.type isEqualToString:@"audio"])
    {
        //FIXME 2.5
        DLog(@"Keep local backup copy of audio before deleting media");
        
        NSString *backupPathDir = [media.path stringByDeletingLastPathComponent];
        NSString *backupPathFilename = [NSString stringWithFormat:@"%@_%@", kMukurtuAudioFileBackupPrefix, [media.path lastPathComponent]];
        NSString *backupPath = [backupPathDir stringByAppendingPathComponent:backupPathFilename];
        
        //move audio file to backup
        //if ([fileManager moveItemAtPath:media.path toPath:backupPath error:&error])
        if ([fileManager moveItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:media.path]
                                 toPath:[NSHomeDirectory() stringByAppendingPathComponent:backupPath] error:&error])
        {
            DLog(@"Succesfully moved AudioFile %@ to backup file %@", media.path, backupPath);
        }
        else
        {
            DLog(@"ERROR: Failed renaming audio file %@ to backup file %@ with error %@, leaving file as is", media.path, backupPath, [error description]);

        }
    }
    else
    {
        DLog(@"Removing file %@", media.path);
        //if (![fileManager removeItemAtPath:media.path error:&error])
        if (![fileManager removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:media.path] error:&error])
            DLog(@"Deleting file error %@, %@", error, [error userInfo]);
        
        DLog(@"Removing file %@", media.thumbnail);
        //if (![fileManager removeItemAtPath:media.thumbnail error:&error])
        if (![fileManager removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:media.thumbnail] error:&error])
            DLog(@"Deleting file error %@, %@", error, [error userInfo]);
        
        if ([media.type isEqualToString:@"video"])
        {
            DLog(@"Media is a video, removing big thumbnail file as well");
            NSString *bigThumbPath = [ImageSaver getBigThumbPathForThumbnail:[NSHomeDirectory() stringByAppendingPathComponent:media.thumbnail]];
            if (bigThumbPath.length)
            {
                DLog(@"Removing file %@", bigThumbPath);
                if (![fileManager removeItemAtPath:bigThumbPath error:&error])
                    DLog(@"Deleting file error %@, %@", error, [error userInfo]);
            }
            else
            {
                DLog(@"Cannot remove big thumbnail, file %@ not found", bigThumbPath);
            }
        }
    }
    
    DLog(@"Removing media object from context");
    
    [media MR_deleteEntity];
    
}

+ (UIImage *)createVideoThumbnailFromFile:(NSString *)filepath
{
    DLog(@"Creating thumbnail from video file %@", [filepath lastPathComponent]);
    NSURL *videoUrl = [NSURL fileURLWithPath:filepath];
    
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoUrl options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    //CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    CMTime time = CMTimeMake(1, 1);
    NSError *error = nil;
    //CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:NULL error:&error];
    
    if (error)
    {
        DLog(@"Thumbnail creation error==%@, Refimage==%@", error, image);
    }
    
    
    UIImage *thumbnail = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    
    return thumbnail;
}

+ (NSString *) getBigThumbPathForThumbnail:(NSString *)thumbnail
{
    NSString *bigThumbPath;
    
    NSString *thumbnailFileBasename = [[thumbnail lastPathComponent] stringByDeletingPathExtension];
    NSString *bigThumbnailFilename = [[NSString stringWithFormat:@"%@_big",thumbnailFileBasename] stringByAppendingPathExtension:@"jpg"];
    
    bigThumbPath = [[thumbnail stringByDeletingLastPathComponent] stringByAppendingPathComponent:bigThumbnailFilename];
    
    DLog(@"Big thumbnail path for thumbnail:%@ is: %@", [thumbnail lastPathComponent], bigThumbPath);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:bigThumbPath])
    {
        DLog(@"Big Thumbnail file %@ exists", [bigThumbPath lastPathComponent]);
    }
    else
    {
        DLog(@"Error! Big Thumbnail file %@ doesn't exists!", [bigThumbPath lastPathComponent]);
        bigThumbPath = nil;
    }
    
    return bigThumbPath;
}

//FIX 2.5: refactor for consistency and fixes a bug when importing portrait images from photoroll
//orientation will be forced up for all photos (since we redraw them accordingly in canvas)
+ (NSMutableDictionary *)extractMetadataFromMediaInfo:(NSDictionary *)info forceOrientationUp:(BOOL)forceUp
{
    DLog(@"Extracting photo metadata from media object %@", info[UIImagePickerControllerMediaURL]);
         
    //copy exif metadata
    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:[info objectForKey:UIImagePickerControllerMediaMetadata]];
    
    DLog(@"Image original metadata %@",[metadata description]);
    
    if (forceUp)
    {
        //force orientation up
        DLog(@"Forcing image orientation up");
        
        [metadata setImageOrientation:UIImageOrientationUp];
    }
    
    return  metadata;
}

+ (UIImage *)extractImageAndFixOrientationFromMediaInfo:(NSDictionary *)info
{
    //Grab image
    UIImage *pickedImage = info[UIImagePickerControllerOriginalImage];
    
    //fix orientation issues!
    UIImage *image = [pickedImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:pickedImage.size interpolationQuality:kCGInterpolationHigh];
    
    return image;
}
@end
