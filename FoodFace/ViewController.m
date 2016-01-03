//
//  ViewController.m
//  FoodFace
//
//  Created by Aaron on 27/10/2015.
//  Copyright © 2015 Aaron. All rights reserved.
//

#import "ViewController.h"
#import "ImageProcessor.h"
#import "ImageProcessorResult.h"
#import <RSKImageCropper/RSKImageCropper.h>

@interface ViewController ()
@end

float const defaultArcMultiplier = 0.02;

@implementation ViewController {
    ImageProcessor *processor;
}

@synthesize sensitivityStepper;

// TODO: resize input image to fixed size (1000x1000)
// TODO: Crop image to largest possible circle
// TODO: detect plate
// TODO: fill extracted regions (holes) on plate
// TODO: select template based on num. extracted contours
// TODO: setup template with bins, bin centroid coordinates, bin surface areas, ordered by surface area (big to small)
// TODO: allow for tweaking arc length multiplier and other input values
// TODO: capture image from camera
// TODO: show processing progress
// TODO: benchmarking

// TODO: crop image to circle (while taking image)
// TODO: support tweaking number of image & polygon rotations allowed (with stepper)

# pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
}

# pragma mark - Image processor

- (void)detectContoursInImage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ImageProcessorResult *result = [ImageProcessorResult new];
        result = [processor prepareImage];
        result = [processor findContours:[self.arcLengthMultiplierField.text floatValue]];
        result = [processor filterContours];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result.images.count > 0) {
                self.outputImageView.image = result.images.firstObject;
            }
        });
    });
}

- (void)convertImageToFoodFace {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ImageProcessorResult *result = [ImageProcessorResult new];
        result = [processor extractContourBoundingBoxImages];
        result = [processor boundingBoxImagesToPolygons];
        result = [processor placePolygonsOnTargetTemplate];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result.results.count > 0) {
                self.outputImageView.image = result.results.firstObject;
            }
        });
    });
}

- (void)setImageForImageProcessor:(UIImage*)image {
    processor = [[ImageProcessor alloc] initWithImage:image];
}

- (void)setArcLengthTestFieldFromFloat:(float)value {
    self.arcLengthMultiplierField.text = [NSString stringWithFormat:@"%.3f",value];
    self.sensitivityStepper.value = value;
}

# pragma mark - IBActions

- (IBAction)takePhoto:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentViewController:picker animated:YES completion:NULL];
}

- (IBAction)detectContours:(id)sender {
    [self detectContoursInImage];
}

- (IBAction)convertImage:(id)sender {
    [self convertImageToFoodFace];
}

- (IBAction)sensitivityStepperValueChanged:(id)sender {
    [self setArcLengthTestFieldFromFloat:self.sensitivityStepper.value];
    [self detectContoursInImage];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = info[UIImagePickerControllerOriginalImage];
    
    [picker dismissViewControllerAnimated:NO completion:^{
        RSKImageCropViewController *imageCropVC = [[RSKImageCropViewController alloc] initWithImage:chosenImage];
        imageCropVC.delegate = self;
        imageCropVC.dataSource = self;
        imageCropVC.cropMode = RSKImageCropModeCustom;
        
        [self presentViewController:imageCropVC animated:NO completion:nil];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - RSKImageCropViewControllerDataSource

- (void)imageCropViewControllerDidCancelCrop:(RSKImageCropViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imageCropViewController:(RSKImageCropViewController *)controller
                   didCropImage:(UIImage *)croppedImage
                  usingCropRect:(CGRect)cropRect
                  rotationAngle:(CGFloat)rotationAngle {
    [self dismissViewControllerAnimated:YES completion:^{
        self.inputImageView.image = croppedImage;
        [self setArcLengthTestFieldFromFloat:defaultArcMultiplier];
        [self setImageForImageProcessor:croppedImage];
        [self detectContoursInImage];
    }];
}

- (void)imageCropViewController:(RSKImageCropViewController *)controller
                  willCropImage:(UIImage *)originalImage {
}

#pragma mark - RSKImageCropViewControllerDelegate

- (CGRect)imageCropViewControllerCustomMaskRect:(RSKImageCropViewController *)controller {
    return [self customImageCropMask:controller];
}

- (UIBezierPath *)imageCropViewControllerCustomMaskPath:(RSKImageCropViewController *)controller {
    return [UIBezierPath bezierPathWithOvalInRect:[self customImageCropMask:controller]];
}

- (CGRect)imageCropViewControllerCustomMovementRect:(RSKImageCropViewController *)controller {
    return controller.maskRect;
}

- (CGRect)customImageCropMask:(RSKImageCropViewController *)controller {
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
    
    int portraitCircleMaskRectInnerEdgeInset = 1;
    CGFloat diameter = MIN(viewWidth, viewHeight) - portraitCircleMaskRectInnerEdgeInset * 2;
    CGSize maskSize = CGSizeMake(diameter, diameter);
    CGRect maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                 (viewHeight - maskSize.height) * 0.5f,
                                 maskSize.width,
                                 maskSize.height);
    
    return maskRect;
}

@end