/*
 * biginspect.cu
 *
 *  Created on: Sep 16, 2017
 *      Author: gabriel
 */

#include "0_Mainparameters.h"
const char * ScratchpadVal2Imagefile = "results/E_Scratchpadloop.pgm";
const char * DistribPosImage = "results/B_DistributionsLoopintern.pgm";
const char * PSFLoopImage = "results/A_PSFloop.pgm";
const char * DistribTestImage = "results/B_DistributionsTest.pgm";

bool biginspect(int stepval) {
	bool boolinspect;
	float MaxPSFLoop = 0.0f, MaxDistribvalid = 0.0f, SumDistribvalid = 0.0f;



	onhost.MaxSimus = displaydata(new_simus, stepval); 	stepval++;

	onhost.MaxRfactor = displaydata(Rfactor, stepval); 	stepval++;

	cout << "HOST: \u24F3 *************************BigLoop terminated ***************************" << endl;
	cout << "HOST: \u24F3 ***********************************************************************" << endl << endl;

	scratchreaddisplay(val2_scratchpad, val2_scratchpad, ScratchpadVal2Imagefile, FALSE);

	boolinspect = ((onhost.MaxSimus == 0.0f) && (onhost.MaxRfactor == 0.0f));

	unsigned char *i_test2PSF = (unsigned char *) calloc(PSFZOOMSQUARE, sizeof(unsigned char));
	unsigned char *i_distribpos = (unsigned char *) calloc(TA.MP * PSFZOOMSQUARE, sizeof(unsigned char));
	unsigned char *j_distribpos = (unsigned char *) calloc(XDistrib * TA.MP * YDistrib_extended, sizeof(unsigned char));
	verbosefile << "SCRATCHPAD \u24EC Path to DistribPos validation ....." << DistribPosImage << endl;

	for (int i = 0; i < PSFZOOMSQUARE; i++)
		MaxPSFLoop = max(MaxPSFLoop, test2_psf[i]);
	for (int i = 0; i < PSFZOOMSQUARE; i++)
		i_test2PSF[i] = 255.0 * test2_psf[i] / MaxPSFLoop;			// Validation image value
	verbosefile << "Max PSF Loop " << MaxPSFLoop << endl;
	sdkSavePGM(PSFLoopImage, i_test2PSF, PSFZoom, PSFZoom);

	for (int i = 0; i < TA.MP * PSFZOOMSQUARE; i++){
		MaxDistribvalid = max(MaxDistribvalid, distribvalidGPU[i]);
		SumDistribvalid += distribvalidGPU[i];
	}
	printf("MaxDistribvalid %f SumDistribvalid %f\n", MaxDistribvalid, SumDistribvalid);
	for (int i = 0; i < TA.MP * PSFZOOMSQUARE; i++){
//		if(i < PSFZOOMSQUARE) printf("i %d value %f\n", i, distribvalidGPU[i]);
		i_distribpos[i] = 255.0 * distribvalidGPU[i] / Maxdistrib;			// Validation image value
	}
	verbosefile << "Max Distrib Validation " << MaxDistribvalid << endl;
	sdkSavePGM(DistribPosImage, i_distribpos, PSFZoom, TA.MP * PSFZoom);

	float MaxDistribtest = 0.0f;
	for (int i = 0; i < TA.MP * ADistrib; i++)
		MaxDistribtest = max(MaxDistribtest, test2_distrib[i]);
	float ratio = 255./MaxDistribtest;
	verbosefile << "Max Distrib Test " << MaxDistribtest << " ratio " << ratio << endl;
	for (int i = 0; i < TA.MP * ADistrib; i++) {
		int tempa = i % ADistrib; int tempb = i / ADistrib;
		if (tempa < XDistrib * YDistrib_extended)
			j_distribpos[tempa + tempb * XDistrib * YDistrib_extended] = ratio * test2_distrib[i];// Validation image value
	}
	sdkSavePGM(DistribTestImage, j_distribpos, XDistrib, TA.MP * YDistrib_extended);

	return (boolinspect);
}

