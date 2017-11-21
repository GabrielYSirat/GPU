/*
 * BigLoop.cu
 *
 *  Created on: Jun 12, 2017
 *      Author: gabriel
 */
/** version without tiles and aggregates: Contains  the next simulation of microimages, in the full measured surface
 *  with optionally number of laser positions below 16 the value of NIMAGESPARALLEL!!
 *  */
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
	int itb = ithreads + blockIdx.x + blockIdx.y + blockIdx.z;
	int itc = blockIdx.x + blockIdx.y * gridDim.x + blockIdx.z * gridDim.x * gridDim.y;

	int distrib_number = blockIdx.z;
	if(!ithreads) printf("block x %d y %d z %d distrib number %d itc %d\n", blockIdx.x, blockIdx.y, blockIdx.z, distrib_number, itc );
	__syncthreads();
	int iprint = !VERBOSELOOP + itb;
	int center_distrib = ((YDistrib / 2) * XDistrib) + XDistrib / 2;
	int center_microimage = (PixZoomo2) * PixZoom + PixZoomo2;
	time_init = clock64();
	time_start = time_init;
#include "startdevice.cu"

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
#include "testthreads.cu"

	__syncthreads();

	/*************************************************************************************************/
	/**O. Initialize zoomed distrib as calculated  by the preprocessing                               /
	 /** the mosaic has to be prepared before hand on the host and copied in global memory            /
	 /************************************************************************************************/
#pragma unroll
	for (int idistrub = ithreads; idistrub < ADistrib; idistrub += THREADSVAL)
			*(shared_distrib + idistrub) = *(original_distrib + idistrub + distrib_number * ADistrib);

#include "testdistrib.tst"

	/*********************  ***********/
	/**A  Outer Loop on aggregates   **/
	/*********************  ***********/
	int tilex = blockIdx.x;
	int tiley = blockIdx.y;
	int tile = tilex + DD.NbTilex * tiley;
	MemoryOffsetscratch = ASCRATCH * (tilex + tiley * DD.NbTilex);
	/************************************************************************************************/
	/******************************               end of A            *******************************/

	/**B. Initialize Scratchpad to previous reconstruction in float : OPTIMIZED, also with aggregates/
	 /** the mosaic has to be prepared before hand on the host and copied in global memory            /
	 /************************************************************************************************/
	scrglobal = scratchpad_matrix + MemoryOffsetscratch;
#pragma unroll
	for (int iscratch = ithreads; iscratch < ASCRATCH; iscratch += THREADSVAL)
		*(Scratchpad + iscratch) = *(scrglobal + iscratch);
#include "testaggregates.tst"
#include "testdevice.cu"
	/*********************************************************************************/
	/**       END of B                                             *******************/

	/**C  Intermediate Loop on images blocks of NIMAGESPARALLEL   ********************/
	/*********************************************************************************/
	/** preparation of intermediate data for each block of NIMAGESPARALLEL************/
	/******************does not worth additional parallelization!*********************/

	for (int iglobal = 0; iglobal < DD.maxLaserintile; iglobal +=
			NIMAGESPARALLEL) { // image number in global tile list
		int zero_posimages = ithreads
				+ (iglobal + tile * DD.maxLaserintile) * NThreads;
		for (int apix = 0; apix < THreadsRatio; apix++)
			distribpos[apix] = distribpos0[apix];

//		if(!iprint)for (int apix = 0; apix < THreadsRatio; apix++)printf("APIX DISTRIB: apix %d distribpos[apix] %d \n", apix, distribpos[apix]);
// validé
		// zero of microimages and simus
		//each thread, for each SM, for each image, on several pixels separated by THREADSVAL of the small block
		register float *pscratch_0[NIMAGESPARALLEL];
		register float *pscratch_1[NIMAGESPARALLEL];
		register float *pscratch_2[NIMAGESPARALLEL];
		register float *pscratch_3[NIMAGESPARALLEL];

		for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {

			// C_1. Transfer from global to shared memory the relative position of the beginning of the scratchpad
			// region impacted by the pPSF,relative to the scratchpad start for each image  of the small group
			if ((iblockima + iglobal) < DD.NbLaserpertile[tile])
				*(image_to_scratchpad_offset_tile + iblockima) =
						*(image_to_scratchpad_offset + iglobal + iblockima)
								- (XSCRATCH + 1) * PSFZoomo2;
			else
				*(image_to_scratchpad_offset_tile + iblockima) =
				dySCR * XSCRATCH + dxSCR - (XSCRATCH + 1) * PSFZoomo2;
			if(!iprint)printf("OFFSET:iblockima %d offset %d iglobal %d DD.NbLaserpertile[tile] %d\n",
					iblockima,*(image_to_scratchpad_offset_tile + iblockima), iglobal, DD.NbLaserpertile[tile]);
			// validé
		}

		// C.2	Initialize new_simu for all pixels of this thread of simus ,THreadsRatio of them, to zero
		// this occurs for each of image iglobal used in this particular thread,
		for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
			new_simu_inregister_float_0[iblockima] = 0.0f;
			new_simu_inregister_float_1[iblockima] = 0.0f;
			new_simu_inregister_float_2[iblockima] = 0.0f;
			new_simu_inregister_float_3[iblockima] = 0.0f;
		}

		// C.3 initialize the scratch position for each image for each pixel of the group dealt in this thread
		for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
			int pos_0 = image_to_scratchpad_offset_tile[iblockima] + ipixel[0]
					+ jpixel[0] * XSCRATCH;
			int pos_1 = image_to_scratchpad_offset_tile[iblockima] + ipixel[1]
					+ jpixel[1] * XSCRATCH;
			int pos_2 = image_to_scratchpad_offset_tile[iblockima] + ipixel[2]
					+ jpixel[2] * XSCRATCH;
			int pos_3 = image_to_scratchpad_offset_tile[iblockima] + ipixel[3]
					+ jpixel[3] * XSCRATCH;
			pscratch_0[iblockima] = (Scratchpad + pos_0); // Change (simplify) in CUDA 9.0
			pscratch_1[iblockima] = (Scratchpad + pos_1);
			pscratch_2[iblockima] = (Scratchpad + pos_2);
			pscratch_3[iblockima] = (Scratchpad + pos_3);
#include "pscratch.cu"
		}
#include "testdevice.cu"

		/**************************************/
		/******D. SIMUS CALCULATION************/
		/**************************************/
		/** D_1 Loop on pPSF on y axis - Medium level loop
		 position on: pPSF from 0 to PSFZoom,
		 * distribution from jpixelPSF pixel position
		 */
		for (int jPSF = 0; jPSF < PSFZoom; jPSF++) {

# pragma unroll
			for (int iPSF = 0; iPSF < PSFZoom; iPSF++) {
				int PSFpos = iPSF + jPSF * PSFZoom;

				for (int apix = 0; apix < THreadsRatio; apix++)
					//				PSFDISVAL[apix] = valid_pixel[apix]  * *(original_distrib + distribpos[apix]);
					PSFDISVAL[apix] = valid_pixel[apix]
							* *(original_PSF + PSFpos)
							* *(original_distrib + distribpos[apix]);
				/** D_3 Inner loops on THreadsRatio pixels block and on block of NIMAGESPARALLEL images require best optimization
				 * */
# pragma unroll
				for (int iblockima = 0; iblockima < NIMAGESPARALLEL;
						iblockima++) {
					float tmp_0 = *(pscratch_0[iblockima]);
					pscratch_0[iblockima]++;
					new_simu_inregister_float_0[iblockima] += PSFDISVAL[0]
							* tmp_0;
					float tmp_1 = *(pscratch_1[iblockima]);
					pscratch_1[iblockima]++;
					new_simu_inregister_float_1[iblockima] += PSFDISVAL[1]
							* tmp_1;
					float tmp_2 = *(pscratch_2[iblockima]);
					pscratch_2[iblockima]++;
					new_simu_inregister_float_2[iblockima] += PSFDISVAL[2]
							* tmp_2;
					float tmp_3 = *(pscratch_3[iblockima]);
					pscratch_3[iblockima]++;
					new_simu_inregister_float_3[iblockima] += PSFDISVAL[3]
							* tmp_3;
#include "TESTPSFDISVAL.cu"
				}
				for (int apix = 0; apix < THreadsRatio; apix++) {
					if ((ithreads + THREADSVAL * apix) == center_microimage) {
						*(distribvalidGPU + iPSF + jPSF * PSFZoom + itc*PSFZOOMSQUARE) =
								*(shared_distrib + distribpos[apix]);
						distribpos[apix]++;  // update intermediate value of distrib
					}
				}
			}  // iPSF loop

			for (int apix = 0; apix < THreadsRatio; apix++) {
				if ((ithreads + THREADSVAL * apix) == center_microimage) {
					*(distribvalidGPU + jPSF * PSFZoom + itc *PSFZOOMSQUARE) = *(shared_distrib + distribpos[apix]);
					distribpos[apix] += XDistrib - PSFZoom; // update intermediate value of distrib for a full line
				}
			}

			for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
				pscratch_0[iblockima] += XSCRATCH - PSFZoom;
				pscratch_1[iblockima] += XSCRATCH - PSFZoom;
				pscratch_2[iblockima] += XSCRATCH - PSFZoom;
				pscratch_3[iblockima] += XSCRATCH - PSFZoom;
			}
		} // loop on PSFpos which spans all PSF values
#include "testdevice.cu"

		for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {	// Removing images which are not valid (putting value to zero)
			new_simu_inregister_float_0[iblockima] = valid_image[iblockima]
					* new_simu_inregister_float_0[iblockima];
			new_simu_inregister_float_1[iblockima] = valid_image[iblockima]
					* new_simu_inregister_float_1[iblockima];
			new_simu_inregister_float_2[iblockima] = valid_image[iblockima]
					* new_simu_inregister_float_2[iblockima];
			new_simu_inregister_float_3[iblockima] = valid_image[iblockima]
					* new_simu_inregister_float_3[iblockima];
		}
#include "testdevice.cu"

		int it = zero_posimages;
# pragma unroll
		for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {
			new_simus[it] = new_simu_inregister_float_0[iblockima];
			new_simus[it + 1 * THREADSVAL] =
					new_simu_inregister_float_1[iblockima];
			new_simus[it + 2 * THREADSVAL] =
					new_simu_inregister_float_2[iblockima];
			new_simus[it + 3 * THREADSVAL] =
					new_simu_inregister_float_3[iblockima];
			it += NThreads;
		}

#ifdef TESTSIMU

		for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++) {

			MaxNewSimus = max(MaxNewSimus,
					new_simu_inregister_float_0[iblockima]);
			MaxNewSimus = max(MaxNewSimus,
					new_simu_inregister_float_1[iblockima]);
			MaxNewSimus = max(MaxNewSimus,
					new_simu_inregister_float_2[iblockima]);
			MaxNewSimus = max(MaxNewSimus,
					new_simu_inregister_float_3[iblockima]);
		}
		if (!iprint)
			printf("DEVICE:\u2467 new simus max %f\n\n", MaxNewSimus);
		__syncthreads();
#endif

//#include "testsimu.tst"
	}
//	*DD.stepval = DD.step;
}

