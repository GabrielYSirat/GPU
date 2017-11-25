/*
 * MainLoop.cu
 *
 *  Created on: November 23, 2017
 *      Author: Gabriel Y Sirat */
/** Contains  the next simulation of microimages, in the full measured surface
 *  with optionally number of laser positions below 16 the value of NIMAGESPARALLEL!!
 *  **/
#include "NewLoop.h"
#define VERBOSELOOP 1
#include "include.tst"
__managed__ float *new_simus , *Data , *Rfactor, *distribvalidGPU;

__managed__ float EnergyGlobal;
__global__ void BigLoop(devicedata DD) {

	extern __shared__ int shared[]; /***************semi-global variables stored in shared memory ***************/
	int *image_to_scratchpad_offset_tile = (int *) shared;// Offset of each image in NIMAGESPARALLEL block
	float *Scratchpad = (float *) &image_to_scratchpad_offset_tile[NIMAGESPARALLEL]; // ASCRATCH floats for Scratchpad
	float *shared_distrib = (float*) &Scratchpad[ASCRATCH]; // XDISTRIB*YDISTRIB floats for distrib

	int MemoryOffsetscratch = 0; // to be redefine with aggregates
	float MaxNewSimus = 0.0f;
	float * scrglobal;

	/*****************constant values & auxiliary variables stored in registers *****************/
	register float PSFDISVAL[MAXTHRRATIO] = { 0.0f };// multiplication of pPSF and distribution
	register int tmpi[MAXTHRRATIO], ipixel[MAXTHRRATIO], jpixel[MAXTHRRATIO],
			valid_pixel[MAXTHRRATIO], distribpos0[MAXTHRRATIO], distribpos[MAXTHRRATIO];

	/****************Larger segmented areas to be stored in registers **************************/
	// new simus values kept in registers for speed issues
	register float new_simu_inregister_float_0[NIMAGESPARALLEL] = { 0.0f };
	register float new_simu_inregister_float_1[NIMAGESPARALLEL] = { 0.0f };
	register float new_simu_inregister_float_2[NIMAGESPARALLEL] = { 0.0f };
	register float new_simu_inregister_float_3[NIMAGESPARALLEL] = { 0.0f };
	// Running position on the scratchpad, different for:

	/***** INITIALIZATION *****************/

	DD.step = 0;
	int ithreads = threadIdx.x;
	int itb = blockIdx.x + blockIdx.y + blockIdx.z;
	int itc = ithreads + blockIdx.x + blockIdx.y * gridDim.x + blockIdx.z * gridDim.x * gridDim.y;
	int distrib_number = blockIdx.z;
	int iprint = !VERBOSELOOP + itc;

	int center_distrib = ((YDistrib / 2) * XDistrib) + XDistrib / 2;
	int center_microimage = (PixZoomo2) * PixZoom + PixZoomo2;
	DD.step++; time_init = clock64();  time_start = time_init;

#ifdef STARTDEVICE
	if (!iprint) { 	// the condition is required to have it printed once
		printf("\n\u2460********************************** START *****************************\n");
		printf("DEVICE: \u2460****************PARAMETERS OF MEASUREMENT *******************\n");
		printf("DEVICE: \u2460 PARAMETERS  NThreads %d Npixel %d pZOOM %d, pPSF %d\n", NThreads, Npixel, pZOOM, pPSF);
		printf("DEVICE: \u2460 PARAMETERS dimBlock  x: %d y: %d z: %d   ...   ", blockDim.x, blockDim.y, blockDim.z);
		printf("dimGrid  x: %d y: %d z: %d\n", gridDim.x, gridDim.y, gridDim.z);
		printf("DEVICE: \u2460 PARAMETERS pPSF %d XDistrib %d YDistrib %d ADistrib %d\n", pPSF, XDistrib, YDistrib, ADistrib);
		printf("DEVICE: \u2460 PARAMETERS XSCRATCH %d YSCRATCH %d XTILE %d YTILE %d\n", XSCRATCH, YSCRATCH, XTile, YTile);
		printf("DEVICE: \u2460 PARAMETERS Number of pixels calculated in parallel %d Number of threads used"
				" %d loop on threads %d\n", NThreads, THREADSVAL, THreadsRatio);
		printf("DEVICE: \u2460  TILES: XSCRATCH %d, YSCRATCH %d  iprint %d", XSCRATCH, YSCRATCH,iprint);
		printf("XTILE %d, YTILE %d\n", XTile, YTile);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Aggregates in x: %d in y:%d\n", DD.NbAggregx,
				DD.NbAggregy);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Tiles per aggregates in x: %d in y:%d\n",
				DD.tileperaggregatex, DD.tileperaggregatey);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Tiles in x: %d in y:%d\n", DD.NbTilex, DD.NbTiley);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Max number of laser position in Tile: %d min value:%d Number of blocks %d\n",
				DD.maxLaserintile, DD.minLaserintile, DD.blocks);
		printf("\u2460*******************************PARAMETERS OF MEASUREMENT ***************\n");
	}
	__syncthreads();
	if(!ithreads && VERBOSELOOP) printf("TEST: block x %d y %d z %d distrib number %d itc %d itb %d\n",
			blockIdx.x, blockIdx.y, blockIdx.z, distrib_number, itc, itb);
	if (!itc) time_start = clock64(); if (!itc) timer = clock64();
		if (!iprint)  	// the condition is required to have it printed once
			printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING ** processing  %g from start  %g  total %g \n\n",
					DD.step, (float) (timer - time_start) / CLOCKS_PER_SEC,
					(float) (  time_start - time_init) / CLOCKS_PER_SEC,
					(float) (timer - time_init) / CLOCKS_PER_SEC);
		__syncthreads();


#endif

	/***************************Basic parameters **************************************************/
	/*************************Threads and pixels related parameters *******************************/

	for (int apix = 0; apix < THreadsRatio; apix++) { // ipixel, jpixel have 0 values too often
		tmpi[apix] = (ithreads + apix * THREADSVAL);
		ipixel[apix] = tmpi[apix] % PixZoom - PixZoomo2; // centered on the center of the zoomed microimage
		jpixel[apix] = tmpi[apix] / PixZoom - PixZoomo2; // centered on the center of the zoomed microimage
		valid_pixel[apix] = tmpi[apix] < PixZoomSquare;
		distribpos0[apix] = center_distrib + ipixel[apix] - PSFZoomo2
				+ (jpixel[apix] - PSFZoomo2) * XDistrib;
	}
#ifdef TESTTHREADS
if (!iprint) printf("\n\u2461*******************************DEVICE:  THREADS *********************\n");

	if (!itb)
		for (int apix = 0; apix < THreadsRatio; apix++){
			if (!ipixel[apix] && !jpixel[apix])
				printf(
						"DEVICE CENTER: \u2461 THREAD3 : apix %d itc %d tmpi %d ipixel %d, jpixel %d  valid %d distribpos0 %d center %d\n",
						apix, itc, tmpi[apix], ipixel[apix], jpixel[apix], valid_pixel[apix],
						distribpos0[apix], center_distrib);
			int tmpi = (ithreads + apix * THREADSVAL);
				if ((ithreads == 0)||(ithreads == (THREADSVAL-1)) ||(tmpi == PixZoomSquare-1) ||(tmpi == PixZoomSquare))
				printf("DEVICE: \u2461 THREAD1 : apix %d  itc %d ipixel %d, jpixel %d  valid %d distribpos0 %d\n",
						apix, itc, ipixel[apix], jpixel[apix], valid_pixel[apix], distribpos0[apix]);
		}
	if (!iprint) printf("\u2461 **********************************DEVICE:  THREADS  ********************\n\n");
__syncthreads();
#endif
/*{
		if(tmpi == (PixZoomSquare-1) || tmpi == PixZoomSquare)
		printf("DEVICE: \u2461 THREAD2 : apix %d itc %d ipixel %d, jpixel %d  valid %d distribpos0 %d\n",
				apix, itc, ipixel[apix], jpixel[apix], valid_pixel[apix], distribpos0[apix]);
		for (int apix = 0; apix < THreadsRatio; apix++)
	}	__syncthreads(); */


}

