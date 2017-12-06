/*
 * 0_Mainparameters.h
 *
 *  Created on: Apr 10, 2017
 *      Author: gabriel
 */

#ifndef NEWLOOP_H_
#define NEWLOOP_H_

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
#include "device_functions.h"
#include <cuda_runtime.h>			// Includes CUDA
#include <helper_functions.h>    	// CUDA helper functions: includes cuda.h and cuda_runtime_api.h
#include <helper_cuda.h>         	// helper functions for CUDA error check
#include <cuda_runtime_api.h>
#include "tinyxml2.h"				// XML package
#include <algorithm>

using namespace tinyxml2;
using namespace std;

#include "0_classloop.h"
#include "0_constantLoop.h"

//#define SINGLETILE
#define DOUBLETILE
#define min(a,b) (a) < (b) ? (a) : (b)
#define max(a,b) (a) > (b) ? (a) : (b)

/*************************FILES*****************/
extern ofstream verbosefile;


/*****************DATA FILES *******************/
extern std::string resourcesdirectory, filename, MIFILE, PSFFILE, DISTRIBFILE;
extern char buff[BUFFSIZE], chars[]; // a buffer to temporarily park the data
extern cudaEvent_t start, stop;
extern double Sumdel[16], Timestep[16];
extern string Stepdiag[16];
extern int smallnumber, byte_skipped, step;
extern int fullnumberoftiles,datafullsize;
extern float Maxdistrib, Sumdistrib;
extern float MaxPSF, SumPSF;
extern float MaxRec, SumRec;
extern float Maxmicroimages, Minmicroimages;
extern __managed__ float Maxscratch, Sumscratch, maxTile, SumTile;
extern __managed__ double MaxNewSimus;


/************Extern read in command line*************/
extern __managed__ int pPSF, Npixel, pZOOM, RDISTRIB, Ndistrib;
extern __managed__ float *Sumdevmicroimages, *Maxdevmicroimages,*Sumdevzoommicroimages, *Maxdevzoommicroimages ;
/************Extern defined in main*************/
extern int clockRate, devID; // in KHz
extern __managed__ clock_t timer, time_init, time_start;

/** parameters derived from the basic parameters
 *
 */
extern __managed__ int XTile, YTile, ATile;
extern __managed__ int THreadsRatio,NThreads;
extern __managed__ int XDistrib, YDistrib, YDistrib_extended, ADistrib;

extern __managed__ double Energy_global, absdiff;


/*********************CLASSES ********************/
extern  GPU_init TA;
extern  COS OFSCAL;
extern  Ctile tile;
extern 	devicedata onhost;

// Declarations, forward
//////////////////////////////////////////////////////////////////////////////

void report_gpu_mem();
bool initparameters(int argc, char **argv);
void stepinit(int test, int & stepval);
int retrieveargv(string argvdata);
bool T4Dto2D( unsigned char *matrix4D, unsigned char *matrix2D,  int dimension1, int dimension2, int dimension3, int dimension4);

/************************pPSF *******************/
void PSFprepare(void);
bool PSFinitondevice(void);
bool PSFvalidateonhost(void);
__global__ void PSFvalidateondevice( int Nb_Rows_PSF, int Nb_Cols_PSF);

/************************Laser positions *********/
void readstoreLaserPositions(void);
bool validateLaserPositions_control(void);
bool tileorganization(void);
__global__ void validateLaserPositions_device( int Nb_LaserPositions);

/**************************ROI********************/
void readstoreCroppedROI(void);
bool validateCroppedROI_control(void);
__global__ void validateCroppedROI_device( int Nb_ROI);


/************************distrib *********/
void readstoredistrib(void);
bool Distribvalidate_host(void);
__global__ void validate_distrib( int Nb_Rows_distrib, int Nb_Cols_distrib, int Nb_Distrib);

/************************Microimages *********/
void readstoremicroimages(void);
bool validatemicroimages_control(void);
__global__ void validate_microimages(int Nb_LaserPositions);
bool microimagesintile(void);
bool initializesimusData(void);


/************************Reconstruction *********/
void Recprepare(void);
bool Recvalidate_host(void);
__global__ void Recvalidate_device(int Nb_Rows_reconstruction, int Nb_Cols_reconstruction);

/************************Scratchpad *********/
void Scratchprepare(void);
__global__ void Scratchvalidate_device(int NbTilex, int NbTiley, int dels);
bool Scratchvalidate_host(void);

bool biglaunch(void), biginspect(int stepval);
float displaydata( float * datavalues, int step);
__global__ void BigLoop(devicedata DD);

/***************************Energy*******************/
float EnergyCal(void);

bool tile_organization(void);
extern __managed__ float *PSF_valid;
extern __managed__ float  *original_PSF, *test2_psf;
extern __managed__ int *ROIx, *ROIy, *d_ROIx, *d_ROIy;
extern __managed__ int *ROIxScratch, *ROIyScratch, *offsetROI;
extern __managed__ float *microimages, *d_microimages;
extern __managed__ float *original_distrib,  *val_distrib, *test_distrib, *test2_distrib;
extern __managed__ double *double_distrib;
extern __managed__ float *original_microimages,  *valmicroimages, *MIintile, *zoomed_microimages;
extern __managed__ float *original_rec,  *val_rec;
extern __managed__ double *double_rec;
extern __managed__ float *scratchpad_matrix,  *val_scratchpad, *val2_scratchpad;
extern __managed__ float *PSFARRAY;

extern __managed__ float *PosLaserx, *PosLasery, *d_PosLaserx, *d_PosLasery;
extern __managed__ int *posxREC, *posyREC;
extern __managed__ int  *PosxScratch,  *PosyScratch, *offsetFULL;
extern __managed__ int *d_PosxScratch, *d_PosyScratch;
extern __managed__ int *d_posxREC, *d_posyREC, *d_offsetFULL;


extern __managed__ int *image_to_scratchpad_offset, *valid_image;
// intermediate data of BigLoop
extern __managed__ float *new_simus, *Data, *Rfactor, *distribvalidGPU;
extern __managed__ int ithreadszerovalue, apixzerovalue;


#endif /* NEWLOOP_H_ */
