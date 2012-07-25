Friendsort
==========
Friendsort is an app that allows you to sort through your Facebook friends by the number of faces that are in the friends' profile pictures.
It is currently hosted at https://sleepy-savannah-9783.herokuapp.com/. (Note: first load may be slower if instance is asleep.)

Frameworks/libraries
-------------------
For the web framework, I ended up with Sinatra. For something as simple as this app and given my newbie status with Ruby, it made sense to use something less featured and more straightforward. Rails has too many bells and whistles that I wouldn’t be using that I’d still have to learn to set up the app and deploy properly.

On the image processing / face detection side of things, there were really two main choices that were available: [OpenCV](http://opencv.willowgarage.com/wiki/) and [ccv](http://libccv.org/). OpenCV is more mature and a slightly more accurate (if what I’ve read is to be believed), but ccv offered a few distinct advantages:
* ccv is written with real-time processing in mind and is several times faster than OpenCV
* It’s written in Javascript, making integration and deployment much simpler (the ruby bindings that I’ve found for OpenCV are either poorly documented or poorly maintained)
* Given that it’s in Javascript, it could be run client-side, meaning a). no need to write back-end infrastructure, workers pool, etc. to process images b). much smaller demands for scaling (though see the “Other” section for a caveat)

For the front-end, it’s just plain vanilla jQuery and Facebook API. There aren’t any complex UI effects or real-time aspects, so there was no need for anything more.
 
Performance
-----------
In my view, this is the biggest issue with the app. The face detection took up to 0.5s per image on my laptop, so processing several hundred friends’ photos takes a long time. I’ve gotten around the issue from a UI perspective by not showing an image until it is processed, but it still kills the CPU while it’s running. In addition, browsers pop up a “scripts on this page are not responsive” if a script has been running for longer than some (varying by browser) period of time. While I haven’t encountered this issue myself, someone with a large number of friends would potentially run into this (depending on browser, CPU speed, etc.).

One potential workaround to this is web workers (newer versions of Firefox and Chrome and possibly some emulation scripts in IE) allow the processing to run in the background and thus not trigger the message. The face detection script supports workers, and the app currently does this for Firefox only (all I’ve tested), but in theory it could be implemented for all browsers. It still hits the CPU though, so responsiveness would be impacted regardless.

A more wholesome solution would be to have an API-like interface (akin to what Face.com had) and an army of workers doing the processing, which would also allow you to cache the results for the same image retrieved by two different users. Building out that infrastructure for that was a bit beyond the scope of what I had envisioned for this project, but it is certainly doable. That would also provide an opportunity to simultaneously test and train different algorithms, which I’d imagine was what Face.com had/has.
 
Accuracy
--------
I’m far from an expert in face detection, but the detection seems rather inaccurate. Even the benchmarks claim (mid-80% areas of accuracy), but just casual observation suggests that this is quite a bit lower. The likely culprit is just the set of images that is used – Facebook profile photos. There are several problems, most of which lead to a false negative (i.e. no face being detected when there’s actually a face):
* Covered faces: There are photos where half the face is covered (e.g. by a dog or the person’s hair); same problem with faces covered with face paint, though I’d imagine that’s much less common
* Obscure faces: Some photos are at a weird angle (e.g. turned to the side)
* Far away faces: Given the resolution of these images, the facial features are too small (number of pixels-wise) to be detected as a face
* Blurry faces (perhaps super-set of the far away faces): The resolution of the image is too low, so a photo has compression artifacts and is blurry enough that the feature detection fails
 
UI
--
Given the variable-height nature of the images, a Pinterest-style layout made the most sense. I originally started with a grid and toyed with cropping the images, but this layout had the least white space and no sacrifices in terms of the images lost. It’s re-calculated when the images are filtered. One area for improvement would be to also watch for browser window resizing and recalculate then as well.
The images displayed are the largest consistent-size images that the API provides. I’ve originally started with the 100px-wide images, but the face detection accuracy dropped significantly, so I ended up using the 200px-wide ones. There potentially is opportunity to mitigate some of the accuracy loss by tweaking some of the face detection script’s parameters, but the 200px images will always have higher accuracy because of the resolution.
 
UX
--
Because each image takes a while to process, what seemed most effective was not showing the image until it’s processed and ready. The processing calls a callback function that figures out the position of the image on the grid, populates some metadata and class info, updates the counters and finally displays the image. There’s a text field at the top that updates as the images are processed, and the counts on the filters are updated as well.
But as mentioned above, the largest issue from a UX standpoint is just the fact that the images take a while to load and kill the CPU while they are loading.
 
Other
-----
Perhaps worth noting is the fact that canvas (which is used by the face detection script) does not honor access-control-allow-origin headers (though Facebook does set them properly), which makes the browsers think it’s a CSRF request. To work around this, I have to proxy the images though the app itself, which retrieves them from Facebook and re-serves them as the response. Hence the /image_proxy requests instead of requests to Facebook directly. This defeats some of the benefits of Facebook’s CDN and forces the web server to serve all the images itself, which is fairly poor from a scaling perspective (both on latency/performance and bandwidth costs).