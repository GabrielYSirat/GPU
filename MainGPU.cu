/*
 * MainGPU.cu
 *
 *  Created on: June 5, 2017
 *      Author: gabriel Sirat
 */

#include "NewLoop.h"

/*******************PARAMETERS**************/
char buff[BUFFSIZE]; // a buffer to temporarily park the data
double Timestep[16];
char chars[] = "[]()", delimeter('=');
int clockRate, devID, stepval = 0; // in KHz
__managed__ clock_t timer, time_init, time_start, time_loop_stop; // in KHz
__managed__ int pPSF, Npixel, RDISTRIB, pZOOM, Ndistrib;
__managed__ double  Energy_Global =0.0f;

cudaEvent_t start, stop, init_t;
float time_event;
std::string resourcesdirectory, filename, name, value;

/************* Classes and structures*******/
GPU_init TA;
COS OFSCAL;
Ctile tile;
devicedata onhost;

__managed__ double Energy_global;

////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv) {


	/***********initialization of  parameters step 0 *******/
	bool InitParameters = initparameters(argc, argv);
	stepinit(InitParameters, stepval);

	/*step 1**********************pPSF initialization ********/
	PSFprepare();
	bool TestPSF = PSFvalidateonhost();
	stepinit(TestPSF, stepval);

	/*step 2 ************distrib initialization **************/
	readstoredistrib();
	bool Testdistrib = Distribvalidate_host();
	stepinit(Testdistrib, stepval);

	/*step 3 ***********************Laser positions***********/
	readstoreLaserPositions();
	bool TestLaserPositions = validateLaserPositions_control();
	stepinit(TestLaserPositions, stepval);

	/*step 4 **************************Cropped ROI************/
	readstoreCroppedROI();
	bool TestROI = validateCroppedROI_control();
	stepinit(TestROI, stepval);

	/*step 5 *********************microimages  ****************/
	readstoremicroimages();
	bool testmicroimages = validatemicroimages_control();
	stepinit(testmicroimages, stepval);

	/*step 6 ************************Laser in tile ************/
	bool Lasertile = tileorganization();
	stepinit(Lasertile, stepval);

	/*step 7 ************************µimages in tile **********/
	bool boolMI = microimagesintile();
	onhost.MaxData = displaydata( Data,  stepval);
	stepinit(boolMI, stepval);

	/*step 8 *********************Reconstruction  *************/
	Recprepare();
	bool testreconstruction = Recvalidate_host();
	stepinit(testreconstruction, stepval);

	/*step 9 *********************Scratchpad  *****************/
	Scratchprepare();
	bool testscratchpad = Scratchvalidate_host();
	stepinit(testscratchpad, stepval);

	report_gpu_mem();

	/*step 10 *********************launch BigLoop  ************/

	bool testLoop = biglaunch();
	stepinit(testLoop, stepval);

	/*step 11 *********************Energy  ********************/
Energy_global = EnergyCal();
	bool testEnergy = (Energy_Global !=0.0f);
	stepinit(testEnergy, stepval);

	/*step 12 *********************Inspect results  ***********/

	bool testinspect = biginspect(stepval);
	stepinit(testinspect, stepval);

}

