#include "0_NewLoop.h"

using namespace tinyxml2;
using namespace std;

#define TEST 1
#define VERBOSEINITLOOP 0

const char * Laserfile = "results/LaserDevice.txt";


//////////////pPSF parameters
//__device__ float PSF_array[pPSF*pZOOM*pPSF*pZOOM]; // pPSF in constant memory

__managed__ float *PSF_valid = NULL, *PSFARRAY = NULL, *original_PSF=NULL;
__managed__ float *distrib = NULL;			 // on device original and for validation
__managed__ float *MicroImages = NULL;				 // on device original and for validation
__managed__ float *LaserPositions = NULL, *v_LaserPositions = NULL;		 // on device original and for validation
__managed__ float *PosLaserx = NULL, *PosLasery = NULL;
__managed__ float *d_PosLaserx, *d_PosLasery;
__managed__ int *PosxScratch = NULL, *PosyScratch = NULL;
__managed__ int *posxREC, *posyREC, *offsetFULL;
__managed__ int *d_PosxScratch = NULL, *d_PosyScratch = NULL;
__managed__ int *d_posxREC, *d_posyREC, *d_offsetFULL;

__managed__ int *ROIx, *ROIy;
__managed__ int *d_ROIx, *d_ROIy;
__managed__ int *ROIxScratch, *ROIyScratch, *offsetROI;
__managed__ float *microimages, *d_microimages;
__managed__ float *original_distrib, *val_distrib, *test_distrib, *test2_distrib;
__managed__ double *double_distrib;
__managed__ float *original_microimages, *valmicroimages, *MIintile, *zoomed_microimages;
__managed__ float *original_rec, *val_rec;
__managed__ double *double_rec;
__managed__ float *scratchpad_matrix, *val_scratchpad, *val2_scratchpad;

__managed__ float *Sumdevmicroimages, *Maxdevmicroimages, *Sumdevzoommicroimages, *Maxdevzoommicroimages;

__global__ void PSFvalidateondevice(int Nb_Rows_PSF, int Nb_Cols_PSF) {
	double SumPSF = 0, maxPSF = 0, Sum2PSF = 0, max2PSF = 0; // in pPSF the Sum of all pixels is normalize to 1.00000
	float tempv;
	time_start = clock64();
	time_init = clock64();
	printf(" PSF \u2776 device: Rows: %d cols: %d ...", Nb_Rows_PSF, Nb_Cols_PSF);
// calculate pPSF on device Sum and max
	for (int row = 0; row < Nb_Rows_PSF; row++)
		for (int col = 0; col < Nb_Cols_PSF; col++) {
			int tempp = row * Nb_Cols_PSF + col;
			tempv = *(original_PSF + tempp);
			PSFARRAY[tempp] = *(original_PSF + tempp);
			if (VERBOSEINITLOOP)
				if ((row == (Nb_Rows_PSF / 4)) && !(col % 8))
					printf(" PSF \u2776  VERBOSE tempv,%g row %d column %d, tempp %d\n", tempv, row, col, tempp);
			*(PSF_valid + tempp) = tempv;
			Sum2PSF += *(PSF_valid + tempp);
			SumPSF += PSFARRAY[tempp];
			if (maxPSF < PSFARRAY[tempp])
				maxPSF = PSFARRAY[tempp];
			if (max2PSF < *(PSF_valid + row * Nb_Cols_PSF + col))
				max2PSF = *(PSF_valid + row * Nb_Cols_PSF + col);
		}
	if ((threadIdx.x == 0) && (threadIdx.y == 0))
		printf("  SumPSF %f Sum2PSF %f maxPSF %f max2PSF %f ...  \n", SumPSF, Sum2PSF, maxPSF,
				max2PSF);
	timer = clock64();
}

__global__ void validate_distrib(int Nb_Rows_distrib, int Nb_Cols_distrib, int Nb_Distrib) {
	double Sumdistrib = 0, maxdistrib = 0, Sum2distrib = 0, max2distrib = 0; // in distrib the Sum of all pixels is normalize to 1.00000
	float tempv;
	int tempp;
	time_start = clock64();
	printf("DISTRIBUTIONS \u2777  device: Nb_Row %d, Nb_col %d, Nb_distrib %d\n", Nb_Rows_distrib, Nb_Cols_distrib,
			Nb_Distrib);
// calculate distrib Sum and max
	for (int idistrib = 0; idistrib < Nb_Distrib; idistrib++)
		for (int row = 0; row < Nb_Rows_distrib; row++)
			for (int col = 0; col < Nb_Cols_distrib; col++) {
				tempp = (idistrib * Nb_Rows_distrib + row) * Nb_Cols_distrib + col;
				tempv = *(original_distrib + tempp);
				if (VERBOSEINITLOOP)
					if (!(row % 31))
						if (!(col % 25))
							printf("DISTRIBUTIONS \u2777  device: tempv,%g idistrib %d row %d"
									" column %d, tempp %d\n", tempv, idistrib, row, col, tempp);
				*(val_distrib + tempp) = tempv;
				Sum2distrib += *(val_distrib + row * Nb_Cols_distrib + col);
				Sumdistrib += *(original_distrib + row * Nb_Cols_distrib + col);
				if (maxdistrib < *(original_distrib + row * Nb_Cols_distrib + col))
					maxdistrib = *(original_distrib + row * Nb_Cols_distrib + col);
				if (max2distrib < *(val_distrib + row * Nb_Cols_distrib + col))
					max2distrib = *(val_distrib + row * Nb_Cols_distrib + col);
			}
	printf("DISTRIBUTIONS \u2777 device: Sum distrib %f Sum2distrib %f \n"
			"DISTRIBUTIONS \u2777           max distrib %f max2distrib %f ...  \n", Sumdistrib, Sum2distrib,
			maxdistrib, max2distrib);
	timer = clock64();

}

__global__ void validateLaserPositions_device(int Nb_LaserPositions) {
	double maxLaserPositionx = 0, maxLaserPositiony = 0; // in LaserPosition the max in x is xmax
	double minLaserPositionx = 1E6, minLaserPositiony = 1E6; // in LaserPosition the max in x is xmax
	int xREC, yREC, tilex, tiley;
// calculate LaserPositions Sum and max
	time_start = clock64();

	for (int ipos = 0; ipos < Nb_LaserPositions; ipos++) {
		d_PosLaserx[ipos] = PosLaserx[ipos];
		d_PosLasery[ipos] = PosLasery[ipos];
		// Laser positions in y zoomed in integer
		xREC = nearbyintf(pZOOM * *(PosLaserx + ipos));
		tilex = xREC / XTile;
		*(PosxScratch + ipos) = (xREC % XTile) + dxSCR / 2; // Laser positions in x zoomed integer in the scratchpad of tile
		yREC = nearbyintf(pZOOM * *(PosLasery + ipos));
		tiley = yREC / YTile;
		*(PosyScratch + ipos) = (yREC % YTile) + dySCR / 2; // Laser positions in x zoomed integer in the scratchpad of tile
		*(offsetFULL + ipos) = *(PosxScratch + ipos) + *(PosyScratch + ipos) * XSCRATCH;
		if (VERBOSEINITLOOP && (ipos < 20)) {
			printf(" Laser \u2778 DEVICE 1: laser position n° %d original position x:%f , y: %f ....\n", ipos,
					PosLaserx[ipos], PosLasery[ipos]);
			printf(" Laser \u2778 DEVICE 2:  ....xREC %d yREC %d tilex %d tiley %d Scratchx %d Scratchy %d \n", xREC,
					yREC, tilex, tiley, PosxScratch[ipos], PosyScratch[ipos]);
			printf(" Laser \u2778 DEVICE 3: copy position: %f y: %f\n\n", d_PosLaserx[ipos], d_PosLasery[ipos]);
		}

		if (minLaserPositionx > PosLaserx[ipos])
			minLaserPositionx = PosLaserx[ipos];
		if (maxLaserPositionx < PosLaserx[ipos])
			maxLaserPositionx = PosLaserx[ipos];
		if (maxLaserPositiony < PosLasery[ipos])
			maxLaserPositiony = PosLasery[ipos];
		if (minLaserPositiony > PosLasery[ipos])
			minLaserPositiony = PosLasery[ipos];
	}
	printf(" Laser \u2778  DEVICE: MAX & MIN: LaserPosition x max %f min %f ... LaserPositiony max %f min %f \n",
			maxLaserPositionx, minLaserPositionx, maxLaserPositiony, minLaserPositiony);
	timer = clock64();

}

__global__ void validateCroppedROI_device(int Nb_ROI) {
	int maxROIx = 0, max2ROIx = 0; // in ROI the max in x is xmax
	int maxROIy = 0, max2ROIy = 0; // in ROI the max in y is ymax
// calculate pPSF Sum and max
	time_start = clock64();
	for (uint row = 0; row < Nb_ROI; row++) {
		d_ROIx[row] = ROIx[row];
		d_ROIy[row] = ROIy[row];
		if ((VERBOSEINITLOOP) && ((row < 10) || !(row % 512))) {
			printf("ROI \u2779 DEVICE:  original ROIx,%d row %d, ROIy %d ....  ", ROIx[row], row, ROIy[row]);
			printf(" copy d_ROIx,%d row %d, d_ROIy %d\n", d_ROIx[row], row, d_ROIy[row]);
		}

		maxROIx = max(maxROIx, d_ROIx[row]);
		max2ROIx = max(max2ROIx, ROIx[row]);
		maxROIy = max(maxROIy, d_ROIy[row]);
		max2ROIy = max(max2ROIy, ROIy[row]);
	}
	if (VERBOSEINITLOOP)
		printf("ROI \u2779 DEVICE: \u21C8 ROI maxROI %d max2ROI %d ...  maxROI %d max2ROI %d .....Nb_ROI %d\n", maxROIx,
			max2ROIx, maxROIy, max2ROIy, Nb_ROI);
	timer = clock64();
}
__managed__ float * SumMI;

__global__ void validate_microimages(int Nb_LaserPositions) {
	float tempv;
	int tempp, tempz;
	int iprint = threadIdx.x + threadIdx.y;
	int iblock = blockIdx.x + blockIdx.y;
	if (!(iprint + iblock))
		time_start = clock64();
	__syncthreads();

	for (int ilaser = 0; ilaser < Nb_LaserPositions; ilaser++)
		for (int row = 0; row < Npixel; row++)
			for (int col = 0; col < Npixel; col++) {
				tempp = (ilaser * Npixel + row) * Npixel + col;
				tempv = *(original_microimages + tempp);
				*(valmicroimages + tempp) = tempv;

				for (int yz = 0; yz < pZOOM; yz++)
					for (int xz = 0; xz < pZOOM; xz++) {
						tempz = ilaser * PixZoomSquare + (row * pZOOM + yz) * PixZoom
								+ pZOOM * col + xz;
				*(zoomed_microimages + tempz) = tempv;
					}
				__syncthreads();
			}
	if (!(iprint + iblock))
		timer = clock64();

}

__global__ void microimages_intiles(int Nb_tiles, int nbLintile) {
}
__global__ void Recvalidate_device(int Nb_Rows_reconstruction, int Nb_Cols_reconstruction) {
	double Sumreconstruction = 0.0f;
	double maxreconstruction = 1.0f;

	float tempv;
	int tempp;
// calculate reconstruction Sum and max
	time_start = clock64();
	for (int row = 0; row < Nb_Rows_reconstruction; row++)
		for (int col = 0; col < Nb_Cols_reconstruction; col++) {
			tempp = row * Nb_Cols_reconstruction + col;
			tempv = *(original_rec + tempp);
			*(val_rec + tempp) = tempv;
			if ((tempv != 0.0f) && (TEST) && VERBOSE) {
				printf(
						"REC \u277D DEVICE ----------------------------------------------------------------------------------------------------\n");
				printf("REC \u277D DEVICE position %d position x: %d y: %d value %f\n", tempp,
						tempp % Nb_Cols_reconstruction, tempp / Nb_Cols_reconstruction, tempv);
				printf(
						"REC \u277D DEVICE ----------------------------------------------------------------------------------------------------\n");
			}
			Sumreconstruction += *(original_rec + row * Nb_Cols_reconstruction + col);
			if (maxreconstruction < *(original_rec + row * Nb_Cols_reconstruction + col))
				maxreconstruction = *(original_rec + row * Nb_Cols_reconstruction + col);
		}
	printf("REC \u277D DEVICE:  Sum reconstruction %f max reconstruction %f ...  ", Sumreconstruction,
			maxreconstruction);
	__syncthreads();
	if ((threadIdx.x == 0) && (threadIdx.y == 0))
		timer = clock64();
	__syncthreads();

}

__global__ void Scratchvalidate_device(int NbTilex, int NbTiley, int dels) {
	float Sumscratchpad = 0.0f, maxscratchpad = 0.0f;
	float tempv;
	int NbTile = NbTilex * NbTiley;
// calculate scratchpad Sum and max
	time_start = clock64();
	for (int tempp = 0; tempp < ASCRATCH * NbTile; tempp++) {
		tempv = *(scratchpad_matrix + tempp);
		*(val_scratchpad + tempp) = tempv;
		Sumscratchpad += *(val_scratchpad + tempp);
		if (maxscratchpad < *(val_scratchpad + tempp))
			maxscratchpad = *(val_scratchpad + tempp);

		if ((*(val_scratchpad + tempp) != 0.0f) && (TEST)) {
			int positionx = (tempp - dels) % (XSCRATCH * NbTilex);
			int positiony = (tempp - dels) / (XSCRATCH * NbTilex);
			if (VERBOSE)
				printf("SCRATCHPAD \u24EC DEVICE TEST:  position %d position x: %d y: %d value %f\n", tempp,
						positionx, positiony, tempv);
		}

	}
	printf("SCRATCHPAD \u24EC DEVICE:  Sum scratchpad %f max scratchpad %f ... \n", Sumscratchpad,
			maxscratchpad);
	timer = clock64();
	__syncthreads();

}

