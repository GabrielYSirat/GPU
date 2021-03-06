/*
 * 6_MainLoop.cu
 *
 *  Created on: November 23, 2017
 *      Author: Gabriel Y Sirat */
/** Contains  the next simulation of microimages, in the full measured surface
 *  with optionally number of laser positions below 16 the value of NIMAGESPARALLEL!!
 *  **/
#include "0_Mainparameters.h"
#define VERBOSELOOP 1
#define SPARSEDATA 1
#include "0_include.tst"
__managed__ float *new_simus, *Data, *Rfactor, *distribvalidGPU;
__managed__ double MaxNewSimus = 0.0f, EnergyGlobal = 0.0f;


__global__ void BigLoop(devicedata DD) {
	extern __shared__ int shared[]; /***************semi-global variables stored in shared memory ***************/
	int *image_to_scratchpad_offset_tile = (int *) shared; // Offset of each image in NIMAGESPARALLEL block
	float *Scratchpad = (float *) &image_to_scratchpad_offset_tile[NIMAGESPARALLEL]; // ASCRATCH floats for Scratchpad
	float *shared_distrib = (float*) &Scratchpad[ASCRATCH]; // ASCRATCH floats for distrib

	/*****************constant values & auxiliary variables stored in registers *****************/
	register float PSFDISVAL[MAXTHRRATIO] = { 0.0f }; // multiplication of pPSF and distribution
	register int tmpi[MAXTHRRATIO], ipixel[MAXTHRRATIO], jpixel[MAXTHRRATIO], valid_pixel[MAXTHRRATIO],
			distribpos0[MAXTHRRATIO], distribpos[MAXTHRRATIO];
	int tilexdevice, tileydevice, tileXY, tileXYD;
	float * scrglobal;

	timer = clock64();
	/***** INITIALIZATION *****************/
	int ithreads = threadIdx.x;
	int distrib_number = blockIdx.z;
	int itb = blockIdx.x + blockIdx.y * gridDim.x + blockIdx.z * gridDim.x * gridDim.y; // Block position
	int itc = ithreads + itb;
	int iprint = !VERBOSELOOP + itc;
	int center_distrib = ((YDistrib / 2) * XDistrib) + XDistrib / 2;
	int center_microimage = (PixZoomo2) * PixZoom + PixZoomo2;
	DD.step = 1;

	time_init = clock64(); time_start = clock64(); timer = clock64();
#include "8_startdevice.cu"

	/*************************Threads and pixels related parameters *******************************/

	for (int apix = 0; apix < THreadsRatio; apix++) {
		tmpi[apix] = (ithreads + apix * THREADSVAL);
		ipixel[apix] = tmpi[apix] % PixZoom - PixZoomo2; // centered on the center of the zoomed microimage
		jpixel[apix] = tmpi[apix] / PixZoom - PixZoomo2; // centered on the center of the zoomed microimage
		valid_pixel[apix] = tmpi[apix] < PixZoomSquare;
		distribpos0[apix] = center_distrib + ipixel[apix] - PSFZoomo2 + (jpixel[apix] - PSFZoomo2) * XDistrib;
	}
#include "8_testthreads.cu"

	/*************************************************************************************************/
	/**O. Initialize zoomed distrib as calculated  by the preprocessing                               /
	 /************************************************************************************************/
#pragma unroll
	for (int idistrub = ithreads; idistrub < ADistrib; idistrub += THREADSVAL)
		*(shared_distrib + idistrub) = *(original_distrib + idistrub + distrib_number * ADistrib);
#include "8_testdistrib.cu" // validated

	/*********************  ***********/
	/**A  Outer Loop on aggregates   **/
	/*********************  ***********/
	for (int aggregx = 0; aggregx < DD.NbAggregx; aggregx++)
		for (int aggregy = 0; aggregy < DD.NbAggregy; aggregy++) {
			tilexdevice = blockIdx.x + aggregx * DD.tileperaggregatex;
			tileydevice = blockIdx.y + aggregy * DD.tileperaggregatey;
			tileXY  = tilexdevice + DD.NbTilex * tileydevice;
			tileXYD = tileXY + distrib_number * DD.NbTileXY;
			int MemoryOffset = ASCRATCH * tileXY;
			scrglobal = scratchpad_matrix + MemoryOffset;
#include "8_testaggreg.cu"

			/**B. Initialize Scratchpad to previous reconstruction in float : OPTIMIZED, also with aggregates/
			 /************************************************************************************************/
#pragma unroll
			for (int iscratch = ithreads; iscratch < ASCRATCH; iscratch += THREADSVAL)
				*(Scratchpad + iscratch) = *(scrglobal + iscratch);
#include "8_testscratch.cu"
			/**       END of B                                             *******************/

			/**C  Intermediate Loop on images blocks of NIMAGESPARALLEL   ********************/
			/*********************************************************************************/
			/** preparation of intermediate data for each block of NIMAGESPARALLEL************/
			register float *pscratch_0[NIMAGESPARALLEL], *pscratch_1[NIMAGESPARALLEL],
								*pscratch_2[NIMAGESPARALLEL], *pscratch_3[NIMAGESPARALLEL];
			/****************Larger segmented areas to be stored in registers, initialized to zero *************************/
			register float NSIF_0[NIMAGESPARALLEL] = { 0.0f }, NSIF_1[NIMAGESPARALLEL] = { 0.0f }, // NSIF New Simulation In Float
					NSIF_2[NIMAGESPARALLEL] = { 0.0f }, NSIF_3[NIMAGESPARALLEL] = { 0.0f };

			for (int iglobal = 0; iglobal < DD.maxLaserintile; iglobal += NIMAGESPARALLEL) { // image number in global tile list
				int zero_posimages = ithreads + (iglobal + tileXYD * DD.maxLaserintile) * NThreads;
				for (int apix = 0; apix < THreadsRatio; apix++) distribpos[apix] = distribpos0[apix];
#include "8_distribpos.cu"

				//Thread, for each SM, for each image, on several pixels separated by THREADSVAL of the small block
				// C_1. Transfer from global to shared memory the relative position of the beginning of the scratchpad for each image
				// C.2 initialize the scratch position for each image for each pixel of the group dealt in this thread
				for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
					*(image_to_scratchpad_offset_tile + iblockima) = *(image_to_scratchpad_offset+ iglobal + iblockima + tileXYD*DD.maxLaserintile);
#include "8_offset.cu"
					int pos_0 = image_to_scratchpad_offset_tile[iblockima] + ipixel[0] + jpixel[0] * XSCRATCH;
					int pos_1 = image_to_scratchpad_offset_tile[iblockima] + ipixel[1] + jpixel[1] * XSCRATCH;
					int pos_2 = image_to_scratchpad_offset_tile[iblockima] + ipixel[2] + jpixel[2] * XSCRATCH;
					int pos_3 = image_to_scratchpad_offset_tile[iblockima] + ipixel[3] + jpixel[3] * XSCRATCH;
					pscratch_0[iblockima] = (Scratchpad + pos_0); // Change (simplify) in CUDA 9.0
					pscratch_1[iblockima] = (Scratchpad + pos_1);
					pscratch_2[iblockima] = (Scratchpad + pos_2);
					pscratch_3[iblockima] = (Scratchpad + pos_3);
#include "8_pscratchtest.cu"
				} // end of blockima small loop

				/**************************************/
				/******D. SIMUS CALCULATION************/
				/**************************************/
				for (int jPSF = 0; jPSF < PSFZoom; jPSF++) { // loop on jPSF on y axis -  0 to PSFZoom

# pragma unroll
					for (int iPSF = 0; iPSF < PSFZoom; iPSF++) { // loop on iPSF on x axis - ... 0 to PSFZoom
						int PSFpos = iPSF + jPSF * PSFZoom;		// PSFpos from 0 to PSFZoom*PSFZoom

						for (int apix = 0; apix < THreadsRatio; apix++)
							PSFDISVAL[apix] = valid_pixel[apix] * *(original_PSF + PSFpos) * *(original_distrib + distribpos[apix]);
				/** D_3 Inner loops on THreadsRatio pixels block and on block of NIMAGESPARALLEL images
						 * require best optimization in assembler **/
# pragma unroll
						for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
							float tmp_0 = *(pscratch_0[iblockima]);
							NSIF_0[iblockima] += PSFDISVAL[0] * tmp_0;
							float tmp_1 = *(pscratch_1[iblockima]);
							NSIF_1[iblockima] += PSFDISVAL[1] * tmp_1;
							float tmp_2 = *(pscratch_2[iblockima]);
							NSIF_2[iblockima] += PSFDISVAL[2] * tmp_2;
							float tmp_3 = *(pscratch_3[iblockima]);
							NSIF_3[iblockima] += PSFDISVAL[3] * tmp_3;
#include "8_testdisval.cu"
							pscratch_0[iblockima]++;pscratch_1[iblockima]++;
							pscratch_2[iblockima]++;pscratch_3[iblockima]++;
						} // iblockima most inner loop
#include "8_testdistribvalA.cu"
						for (int apix = 0; apix < THreadsRatio; apix++) distribpos[apix]++;  // update intermediate value of distrib
					} // iPSF loop
#include "8_testdistribvalB.cu"

					for (int apix = 0; apix < THreadsRatio; apix++) distribpos[apix] += XDistrib - PSFZoom; // update intermediate value of distrib for a full line
					for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
						pscratch_0[iblockima] += XSCRATCH - PSFZoom; pscratch_1[iblockima] += XSCRATCH - PSFZoom;
						pscratch_2[iblockima] += XSCRATCH - PSFZoom; pscratch_3[iblockima] += XSCRATCH - PSFZoom;
					} // small loop on iblockima
				} // loop on jPSF

				int it = zero_posimages;
		# pragma unroll
				for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
					new_simus[it                 ] = valid_image[iblockima] * NSIF_0[iblockima];
					new_simus[it + 1 * THREADSVAL] = valid_image[iblockima] * NSIF_1[iblockima];
					new_simus[it + 2 * THREADSVAL] = valid_image[iblockima] * NSIF_2[iblockima];
					new_simus[it + 3 * THREADSVAL] = valid_image[iblockima] * NSIF_3[iblockima];
					it += NThreads;
				} // end intermediate loop on iblockima
			} // end of iglobal loop
		} // end of Aggregates loop
	if(!iprint && VERBOSE) printf("Energy %8.6f absolute difference %8.6f\n\n", EnergyGlobal, absdiff);
} // end of 6_MainLoop

