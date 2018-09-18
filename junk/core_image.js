
print("Hello");

var url = NSURL.fileURLWithPath_("/Library/Desktop Pictures/Galaxy.jpg");
print(url);

var img = CIImage.imageWithContentsOfURL_(url)
print(img);

var f = CIFilter.filterWithName_("CIColorInvert");
print(f);

f.setValue_forKey_(img, kCIInputImageKey);

var r = f.outputImage();

print(r)