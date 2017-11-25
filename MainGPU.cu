/*
 * MainGPU.cu
 *
 *  Created on: June 5, 2017
 *      Author: gabriel Sirat
 */

#include "0_NewLoop.h"
#include <iostream>
#include <fstream>
	  ofstream verbosefile;



/************* Classes and structures*******/
GPU_init TA;
COS OFSCAL;
Ctile tile;
devicedata onhost;
int clockRate, devID, stepval = 0; // in KHz


////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv) {

	  verbosefile.open ("results/verbosefile.txt");
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
	initializesimusData();
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
	bool testEnergy = (Energy_global !=0.0f);
	stepinit(testEnergy, stepval);


	/*step 11 *********************Gradient  ********************/



	/*step 12 *********************Inspect results  ***********/

	bool testinspect = biginspect(stepval);
	stepinit(testinspect, stepval);
	verbosefile.close();


}

