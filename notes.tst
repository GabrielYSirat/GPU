/*
 * 	Organization of GPU:
 gridDim, which regroup the available MPs, is a 3D vector with:
 number of blocks in x  equal to the number of tiles in x per aggregate
 number of blocks in y  equal to the number of tiles in y per aggregate
 number of blocks in z equal the number of distrib
 For example for a Titan Xp, with 28 MP, gridDim is {2, 3, 4} and uses 24 MP
 BlockDim which defines the number of threads requires to be a multiple of 32;
 it is a 1D vector with Npixel*Npixel size rounded to the next multiple of 32,
 and not a 2D of Npixel, which is not efficient.
 */

/******************************************************************************/

// !! REQUIRED: To define offsets relative to the reconstruction grid of microimages, pPSF, distrib, ROI and laser impact
// !! REQUIRED: to include all parameters in a header and to harmonize with NewLoop
// !! REQUIRED: fit parameters and variables between newLoop and BigLoop
// !! REQUIRED: to switch to FP16 with CUDA 9.0
// Managed variables are available in CPU and GPU

// Scratchpad size is ASCRATCH,  XSCRATCH*YSCRATCH completed to the next multiple of NTHREADVAL
