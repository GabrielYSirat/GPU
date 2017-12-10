/*
 * 0_Mainparameters.h
 *
 *  Created on: Apr 10, 2017
 *      Author: gabriel
 */

#ifndef NEWLOOP_H_
#define NEWLOOP_H_

// Includes, system
#include "0_commonparameters.h"
#include "tinyxml2.h"				// XML package
#include "0_classloop.h"
#include "0_commonparameters.h"

using namespace tinyxml2;
using namespace std;

/*************************FILES*****************/
extern ofstream verbosefile;

/*****************DATA FILES *******************/
extern std::string resourcesdirectory, filename, MIFILE, PSFFILE, DISTRIBFILE;
extern char buff[BUFFSIZE], chars[]; // a buffer to temporarily park the data
extern cudaEvent_t start, stop;
extern double Sumdel[16];
extern string Stepdiag[16];
extern int byte_skipped, step;
extern int fullnumberoflasers,datafullsize;
extern float Maxdistrib, Sumdistrib;
extern float MaxPSF, SumPSF;
extern float MaxRec, SumRec;
extern float Maxmicroimages, Minmicroimages;

extern __managed__ float Maxscratch, Sumscratch, maxTile, SumTile;
extern __managed__ double MaxNewSimus;

/*********************CLASSES ********************/
extern  GPU_init TA;
extern  COS OFSCAL;
extern  Ctile tile;

// Declarations, forward
//////////////////////////////////////////////////////////////////////////////
void report_gpu_mem();
bool initparameters(int argc, char **argv);
void stepinit(int test, int & stepval);
int retrieveargv(string argvdata);
bool T4Dto2D( unsigned char *matrix4D, unsigned char *matrix2D,  int dimension1, int dimension2, int dimension3, int dimension4);
float scratchreaddisplay (float * reconstructiondata, float * scratchdata, const char * filename, bool readtile);
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
extern __managed__ float *original_microimages,  *valmicroimages, *zoomed_microimages;
extern __managed__ float *original_rec,  *val_rec;
//extern double *double_rec;
extern __managed__ float *scratchpad_matrix,  *val_scratchpad, *val2_scratchpad;
extern __managed__ float *PSFARRAY;

extern __managed__ float *PosLaserx, *PosLasery, *d_PosLaserx, *d_PosLasery;
extern __managed__ int *posxREC, *posyREC;
extern __managed__ int  *PosxScratch,  *PosyScratch, *offsetFULL;
extern __managed__ int *d_PosxScratch, *d_PosyScratch;
extern __managed__ int *d_posxREC, *d_posyREC, *d_offsetFULL;

// intermediate data of Main Loop
extern __managed__ float *new_simus, *Data, *Rfactor, *distribvalidGPU;

#endif /* NEWLOOP_H_ */
