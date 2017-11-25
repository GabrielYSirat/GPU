/*
 * MainLoop.cu
 *
 *  Created on: November 23, 2017
 *      Author: Gabriel Y Sirat */
/** Contains  the next simulation of microimages, in the full measured surface
 *  with optionally number of laser positions below 16 the value of NIMAGESPARALLEL!!
 *  **/
#include "0_NewLoop.h"
#define VERBOSELOOP 1
#include "include.tst"
__managed__ float *new_simus, *Data, *Rfactor, *distribvalidGPU;
__managed__ float EnergyGlobal;

__global__ void BigLoop(devicedata DD) {

	extern __shared__ int shared[]; /***************semi-global variables stored in shared memory ***************/
	int *image_to_scratchpad_offset_tile = (int *) shared; // Offset of each image in NIMAGESPARALLEL block
	float *Scratchpad = (float *) &image_to_scratchpad_offset_tile[NIMAGESPARALLEL]; // ASCRATCH floats for Scratchpad
	float *shared_distrib = (float*) &Scratchpad[ASCRATCH]; // ASCRATCH floats for distrib

	int MemoryOffsetscratch = 0; // to be redefine with aggregates
	float MaxNewSimus = 0.0f;
	float * scrglobal;

	/*****************constant values & auxiliary variables stored in registers *****************/
	register float PSFDISVAL[MAXTHRRATIO] = { 0.0f }; // multiplication of pPSF and distribution
	register int tmpi[MAXTHRRATIO], ipixel[MAXTHRRATIO], jpixel[MAXTHRRATIO], valid_pixel[MAXTHRRATIO],
			distribpos0[MAXTHRRATIO], distribpos[MAXTHRRATIO];

	/****************Larger segmented areas to be stored in registers **************************/
	// new simus values kept in registers for speed issues
	register float new_simu_inregister_float_0[NIMAGESPARALLEL] = { 0.0f };
	register float new_simu_inregister_float_1[NIMAGESPARALLEL] = { 0.0f };
	register float new_simu_inregister_float_2[NIMAGESPARALLEL] = { 0.0f };
	register float new_simu_inregister_float_3[NIMAGESPARALLEL] = { 0.0f };
	// Running position on the scratchpad, different for:

	/***** INITIALIZATION *****************/

	int ithreads = threadIdx.x; int distrib_number = blockIdx.z;
	int itb = blockIdx.x + blockIdx.y * gridDim.x + blockIdx.z * gridDim.x * gridDim.y; int itc = ithreads + itb;
	int iprint = !VERBOSELOOP + itc; int jprint = !VERBOSELOOP + itb;

	int center_distrib = ((YDistrib / 2) * XDistrib) + XDistrib / 2;
	int center_microimage = (PixZoomo2) * PixZoom + PixZoomo2;
	DD.step = 1; time_init = clock64(); time_start = time_init;

#include "8_startdevice.cu"

	/***************************Basic parameters **************************************************/
	/*************************Threads and pixels related parameters *******************************/

	for (int apix = 0; apix < THreadsRatio; apix++) { // ipixel, jpixel have 0 values too often
		tmpi[apix] = (ithreads + apix * THREADSVAL);
		ipixel[apix] = tmpi[apix] % PixZoom - PixZoomo2; // centered on the center of the zoomed microimage
		jpixel[apix] = tmpi[apix] / PixZoom - PixZoomo2; // centered on the center of the zoomed microimage
		valid_pixel[apix] = tmpi[apix] < PixZoomSquare;
		distribpos0[apix] = center_distrib + ipixel[apix] - PSFZoomo2 + (jpixel[apix] - PSFZoomo2) * XDistrib;
	}
#include "8_testthreads.cu"

	/*************************************************************************************************/
	/**O. Initialize zoomed distrib as calculated  by the preprocessing                               /
	 /** the mosaic has to be prepared before hand on the host and copied in global memory            /
	 /************************************************************************************************/
#pragma unroll
	for (int idistrub = ithreads; idistrub < ADistrib; idistrub += THREADSVAL)
			*(shared_distrib + idistrub) = *(original_distrib + idistrub + distrib_number * ADistrib);

#include "8_testdistrib.cu"
}

