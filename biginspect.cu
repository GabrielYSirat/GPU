/*
 * biginspect.cu
 *
 *  Created on: Sep 16, 2017
 *      Author: gabriel
 */

#include "0_NewLoop.h"
bool biginspect(int stepval) {
	bool boolinspect;
	float MaxScratchpad = 0.0f, SumScratchpad = 0.0f;
//	float MaxDispos = 0.0f, SumDispos = 0.0f;

	onhost.MaxSimus = displaydata(new_simus, stepval);

	stepval ++;

	onhost.MaxRfactor = displaydata(Rfactor, stepval);



	std::cout << "HOST: \u24F3 *************************BigLoop terminated ***************************" << endl;
	std::cout << "HOST: \u24F3 ***********************************************************************" << endl << endl;
	unsigned char *i_Scratchpad = (unsigned char *) calloc(XSCRATCH * YSCRATCH * tile.NbTile, sizeof(unsigned char)); // on host
	const char * ScratchpadVal2Imagefile = "results/ScratchpadVal2Imagefile.pgm";

	for (int arg = 0; arg < ASCRATCH * tile.NbTile; arg++)		SumScratchpad += *(val_scratchpad + arg);
	for (int arg = 0; arg < ASCRATCH * tile.NbTile; arg++)   	MaxScratchpad = max(MaxScratchpad, *(val_scratchpad + arg));
	for (int ity = 0; ity < tile.NbTiley; ity++)
		for (int itx = 0; itx < tile.NbTilex; itx++) {
			int it = itx + ity * tile.NbTilex;
			for (int arg = lostpixels; arg < XSCRATCH * YSCRATCH + lostpixels; arg++) {
				int arg1D = arg + it * ASCRATCH;
				int argy = (arg - lostpixels) / XSCRATCH;
				int argx = (arg - lostpixels) % XSCRATCH;
				int arg2D = argx + itx * XSCRATCH + argy * XSCRATCH * tile.NbTilex
						+ ity * YSCRATCH * XSCRATCH * tile.NbTilex;
				i_Scratchpad[arg2D] = 255.0 * val2_scratchpad[arg1D] / MaxScratchpad;		// Validation image value
				if (val2_scratchpad[arg1D] != 0.0f)
					printf(
							"DEVICE TEST in big.cu: SCRATCHPAD :  arg1D %d, arg2D %d, argx %d, argy %d  value %f  max %f\n",
							arg1D, arg2D, argx, argy, val2_scratchpad[arg1D], MaxScratchpad);
			}
		}

	printf("SCRATCHPAD \u24EC Path to Scratchpad validation %s .....\n", ScratchpadVal2Imagefile);
	sdkSavePGM(ScratchpadVal2Imagefile, i_Scratchpad, XSCRATCH * tile.NbTilex, YSCRATCH * tile.NbTiley);
	for (int i = 0; i < XSCRATCH * YSCRATCH + lostpixels; i++) {
		if (MaxScratchpad < val2_scratchpad[i])
			MaxScratchpad = val2_scratchpad[i]; // sanity check, check max
	}
	std::cout << "max device after BigLoop =" << MaxScratchpad << "\n";
	for (int i = 0; i < XSCRATCH * YSCRATCH + lostpixels; i++)
		i_Scratchpad[i - lostpixels] = 255.0 * val2_scratchpad[i] / MaxScratchpad;			// Validation image value


	sdkSavePGM(ScratchpadVal2Imagefile, i_Scratchpad, XSCRATCH, YSCRATCH);

	boolinspect = ((onhost.MaxSimus == 0.0f)&&(onhost.MaxRfactor==0.0f));

	unsigned char *i_distribpos = (unsigned char *) calloc(TA.MP* PSFZOOMSQUARE, sizeof(unsigned char)); // on host
	unsigned char *j_distribpos = (unsigned char *) calloc(XDistrib * TA.MP * YDistrib_extended, sizeof(unsigned char)); // on host
	const char * DistribPosImage = "results/DistribPos.pgm";
	const char * DistribTestImage = "results/DistribTest.pgm";
	printf("SCRATCHPAD \u24EC Path to DistribPos validation %s .....\n", DistribPosImage);


	for (int i = 0; i < TA.MP * PSFZOOMSQUARE; i++)	i_distribpos[i] = 255.0 * distribvalidGPU[i] / Maxdistrib;			// Validation image value
	sdkSavePGM(DistribPosImage, i_distribpos, PSFZoom, TA.MP * PSFZoom);

	for (int i = 0; i < TA.MP * ADistrib; i++)	{
		int tempa = i%ADistrib;
		int tempb = i/ADistrib;
		if (tempa < XDistrib * YDistrib_extended)
		j_distribpos[tempa + tempb * XDistrib * YDistrib_extended ] = 255.0 * test2_distrib[i] / Maxdistrib;			// Validation image value
	}
	sdkSavePGM(DistribTestImage, j_distribpos, XDistrib, TA.MP * YDistrib_extended);

	return (boolinspect);
}

