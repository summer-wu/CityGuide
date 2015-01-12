//
// Copyright 2011-2014 Jeff Verkoeyen
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "PlacePhotoAlbumViewController.h"
#import "AFNetworking.h"
#import "Gallery.h"
#import "Constants.h"

#import "UIUserSettings.h"


@implementation PlacePhotoAlbumViewController{
    UIUserSettings *_userSettings;
}


- (id)initWith:(id)object {
  if ((self = [self initWithNibName:nil bundle:nil])) {
    self.apiPath = object;
  }
  return self;
}

- (void)loadThumbnails {
  
  NSLog(@"PlacePhotoAlbumViewController. loadThumbnails. photoInformation: %@", _photoInformation);
  
  for (NSInteger ix = 0; ix < [_photoInformation count]; ++ix) {
    NSDictionary* photo = [_photoInformation objectAtIndex:ix];

    NSString* photoIndexKey = [self cacheKeyForPhotoIndex:ix];

    // Don't load the thumbnail if it's already in memory.
    if (![self.thumbnailImageCache containsObjectWithName:photoIndexKey]) {
      NSString* source = [photo objectForKey:@"thumbnailSource"];
      [self requestImageFromSource: source
                         photoSize: NIPhotoScrollViewPhotoSizeThumbnail
                        photoIndex: ix];
    }
  }
}

- (void (^)(AFHTTPRequestOperation *operation, id JSON))blockForAlbumProcessing {
  return ^(AFHTTPRequestOperation *operation, id object) {
    
    NSArray* data = [object objectForKey:@"shots"];
    NSLog(@"PlacePhotoAlbumViewController. blockForAlbumProcessing: %@", data);

    
    NSMutableArray* photoInformation = [NSMutableArray arrayWithCapacity:[data count]];
    for (NSDictionary* photo in data) {
      
      // Gather the high-quality photo information.
      NSString* originalImageSource = [photo objectForKey:@"image_url"];
      NSInteger width = [[photo objectForKey:@"width"] intValue];
      NSInteger height = [[photo objectForKey:@"height"] intValue];
      
      // We gather the highest-quality photo's dimensions so that we can size the thumbnails
      // correctly until the high-quality image is downloaded.
      CGSize dimensions = CGSizeMake(width, height);
      
      NSString* thumbnailImageSource = [photo objectForKey:@"image_teaser_url"];
      
      NSDictionary* prunedPhotoInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                       originalImageSource, @"originalSource",
                                       thumbnailImageSource, @"thumbnailSource",
                                       [NSValue valueWithCGSize:dimensions], @"dimensions",
                                       nil];
      [photoInformation addObject:prunedPhotoInfo];
    }
    
    _photoInformation = photoInformation;
    
    [self loadThumbnails];
    [self.photoAlbumView reloadData];
    [self.photoScrubberView reloadData];

    [self refreshChromeState];
  };
}

- (void)loadAlbumInformation {
  
  NSString* albumURLPath = [@"http://api.dribbble.com" stringByAppendingString:self.apiPath];
  
   NSLog(@"PlacePhotoAlbumViewController. loadAlbumInformation: %@", albumURLPath);

  // Nimbus processors allow us to perform complex computations on a separate thread before
  // returning the object to the main thread. This is useful here because we perform sorting
  // operations and pruning on the results.
  NSURL* url = [NSURL URLWithString:albumURLPath];
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];

  AFHTTPRequestOperation* albumRequest = [[AFHTTPRequestOperation alloc] initWithRequest:request];
  albumRequest.responseSerializer = [AFJSONResponseSerializer serializer];
  [albumRequest setCompletionBlockWithSuccess:[self blockForAlbumProcessing] failure:nil];
  [self.queue addOperation:albumRequest];
}

-(void)createAlbum{
    NSMutableArray* photoInformation = [NSMutableArray arrayWithCapacity:self.aPlace.gallery.count];
    for(Gallery *aGallery in self.aPlace.gallery){
        
        CGSize dimensions = CGSizeZero;//CGSizeMake(width, height);
        
        NSString *thumbnailImageSource = [NSString stringWithFormat:@"%@%@", URL_BASE, aGallery.photo_small];
        NSString *originalImageSource = [NSString stringWithFormat:@"%@%@", URL_BASE, aGallery.photo_big];
        NSDictionary* prunedPhotoInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                         originalImageSource, @"originalSource",
                                         thumbnailImageSource, @"thumbnailSource",
                                         [NSValue valueWithCGSize:dimensions], @"dimensions",
                                         nil];
        [photoInformation addObject:prunedPhotoInfo];
    }
    
    _photoInformation = photoInformation;
    [self loadThumbnails];
    [self.photoAlbumView reloadData];
    [self.photoScrubberView reloadData];
    
    [self refreshChromeState];
}

#pragma mark - UIViewController


- (void)loadView {
  [super loadView];
  
  NSLog(@"PlacePhotoAlbumViewController. loadView");

  self.photoAlbumView.dataSource = self;
  self.photoScrubberView.dataSource = self;

  // Dribbble is for mockups and designs, so we don't want to allow the photos to be zoomed
  // in and become blurry.
  self.photoAlbumView.zoomingAboveOriginalSizeIsEnabled = NO;

  // This title will be displayed until we get the results back for the album information.
  self.title = NSLocalizedString(@"Loading...", @"Navigation bar title - Loading a photo album");
    
    self.navigationController.navigationBar.translucent = NO;

  //[self loadAlbumInformation];
    _userSettings = [[UIUserSettings alloc] init];
    [self setNavBarButtons];
    
    [self createAlbum];
}

- (void)viewDidUnload {
  _photoInformation = nil;

  [super viewDidUnload];
}

#pragma mark - Navigation bar
-(void)setNavBarButtons{
    
    self.navigationItem.leftBarButtonItem = [_userSettings setupBackButtonItem:self];// ====== setup back nav button ====
    self.navigationItem.leftBarButtonItem.tintColor = kDefaultNavItemTintColor;
    //NSLog(@"self.navigationItem.title = %@", self.aPlace);
    
}

-(void)goBack{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - NIPhotoScrubberViewDataSource


- (NSInteger)numberOfPhotosInScrubberView:(NIPhotoScrubberView *)photoScrubberView {
  
  NSLog(@"PlacePhotoAlbumViewController. numberOfPhotosInScrubberView");
  return [_photoInformation count];
}

- (UIImage *)photoScrubberView: (NIPhotoScrubberView *)photoScrubberView
              thumbnailAtIndex: (NSInteger)thumbnailIndex {
  
  NSLog(@"PlacePhotoAlbumViewController. photoScrubberView");
  NSString* photoIndexKey = [self cacheKeyForPhotoIndex:thumbnailIndex];
  
  UIImage* image = [self.thumbnailImageCache objectWithName:photoIndexKey];
  if (nil == image) {
    NSDictionary* photo = [_photoInformation objectAtIndex:thumbnailIndex];
    
    NSString* thumbnailSource = [photo objectForKey:@"thumbnailSource"];
    [self requestImageFromSource: thumbnailSource
                       photoSize: NIPhotoScrollViewPhotoSizeThumbnail
                      photoIndex: thumbnailIndex];
  }
  
  return image;
}

#pragma mark - NIPhotoAlbumScrollViewDataSource


- (NSInteger)numberOfPagesInPagingScrollView:(NIPhotoAlbumScrollView *)photoScrollView {
  NSLog(@"PlacePhotoAlbumViewController. numberOfPagesInPagingScrollView");
  
  return [_photoInformation count];
}

- (UIImage *)photoAlbumScrollView: (NIPhotoAlbumScrollView *)photoAlbumScrollView
                     photoAtIndex: (NSInteger)photoIndex
                        photoSize: (NIPhotoScrollViewPhotoSize *)photoSize
                        isLoading: (BOOL *)isLoading
          originalPhotoDimensions: (CGSize *)originalPhotoDimensions {
  NSLog(@"PlacePhotoAlbumViewController. photoAlbumScrollView");
  
  UIImage* image = nil;

  NSString* photoIndexKey = [self cacheKeyForPhotoIndex:photoIndex];

  NSDictionary* photo = [_photoInformation objectAtIndex:photoIndex];

  // Let the photo album view know how large the photo will be once it's fully loaded.
  *originalPhotoDimensions = [[photo objectForKey:@"dimensions"] CGSizeValue];

  image = [self.highQualityImageCache objectWithName:photoIndexKey];
  if (nil != image) {
    *photoSize = NIPhotoScrollViewPhotoSizeOriginal;

  } else {
    NSString* source = [photo objectForKey:@"originalSource"];
    [self requestImageFromSource: source
                       photoSize: NIPhotoScrollViewPhotoSizeOriginal
                      photoIndex: photoIndex];

    *isLoading = YES;

    // Try to return the thumbnail image if we can.
    image = [self.thumbnailImageCache objectWithName:photoIndexKey];
    if (nil != image) {
      *photoSize = NIPhotoScrollViewPhotoSizeThumbnail;

    } else {
      // Load the thumbnail as well.
      NSString* thumbnailSource = [photo objectForKey:@"thumbnailSource"];
      [self requestImageFromSource: thumbnailSource
                         photoSize: NIPhotoScrollViewPhotoSizeThumbnail
                        photoIndex: photoIndex];

    }
  }

  return image;
}

- (void)photoAlbumScrollView: (NIPhotoAlbumScrollView *)photoAlbumScrollView
     stopLoadingPhotoAtIndex: (NSInteger)photoIndex {
  // TODO: Figure out how to implement this with AFNetworking.
  NSLog(@"PlacePhotoAlbumViewController. photoAlbumScrollView");
}

- (id<NIPagingScrollViewPage>)pagingScrollView:(NIPagingScrollView *)pagingScrollView pageViewForIndex:(NSInteger)pageIndex {
  NSLog(@"PlacePhotoAlbumViewController. pagingScrollView");
  return [self.photoAlbumView pagingScrollView:pagingScrollView pageViewForIndex:pageIndex];
}

@end