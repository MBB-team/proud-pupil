# proud-pupil
A collection of helpful functions for the analysis of pupil dilation.

You can add this as a submodule to your git repository. In your project, use `git submodule add https://github.com/MBB-team/proud-pupil.git` to add,  `git submodule init` to initialize your local configuration file, and `git submodule update` to fetch updates.


## Preprocessing
A typical preprocessing includes the following steps:

1. Remove non-good states of eye-tracker (blinks etc.)
2. Removed fixations outside screen center
3. TODO Correct for gaze position (The pupil will be more ellipsodal when looking at the borders of the screen)
4. Excluded samples outside 3 SD (of the full session)
5. Linear interpolation of missing samples +- 100ms
6. 128s high-pass filter
7. Average eyes (only needed for EyeTribe)
8. Downsampling (only needed for eyelink 1kHz --> 250Hz)
9. Smoothing (for 1D-RFT, Kernel or low-pass 2 Hz) 
10. Z-score across the whole session
11. Baseline correction in epochs (substract mean of 100ms before onset from epoch)
