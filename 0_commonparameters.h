/*
 * 0_Mainparameters.h
 *
 *  Created on: Apr 10, 2017
 *      Author: gabriel
 */

#ifndef COMMON_H_
#define COMMON_H_

// Includes, system
#include <cuda.h>
#include <math.h>
#include <cstdio>
#include <ctime>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <math.h>
#include <fstream>
#include <cuda_runtime.h>			// Includes CUDA
#include <helper_functions.h>    	// CUDA helper functions: includes cuda.h and cuda_runtime_api.h
#include <helper_cuda.h>         	// helper functions for CUDA error check
#include <cuda_runtime_api.h>
#include <algorithm>
#include "device_functions.h"

#include "0_classloop.h"
#include "0_constants.h"
#include "0_constantsloop.h"

#define min(a,b) (a) < (b) ? (a) : (b)
#define max(a,b) (a) > (b) ? (a) : (b)

/************Extern read in command line*************/
extern __managed__ int pPSF, Npixel, pZOOM, RDISTRIB, Ndistrib;
/************Extern defined in main*************/
extern int clockRate, devID; // clockRate in KHz
extern __managed__ clock_t timer, time_init, time_start;

/** parameters derived from the basic parameters
 *
 */
extern __managed__ int XTile, YTile, ATile;
extern __managed__ int THreadsRatio,NThreads;
extern __managed__ int XDistrib, YDistrib, YDistrib_extended, ADistrib;
extern __managed__ double Energy_global, absdiff;

/** Arrays used in the main loop
 *
 */
extern __managed__ float  *original_PSF, *test2_psf;
extern __managed__ float *scratchpad_matrix, *val2_scratchpad;
extern __managed__ float *original_distrib,  *test2_distrib;
extern __managed__ int *image_to_scratchpad_offset, *valid_image;

/*********************CLASSES ********************/
extern 	devicedata onhost;

#endif /* COMMON_H_ */
