/*
 * readLaserPositions.cu
 *
 *  Created on: Apr 18, 2017
 *      Author: gabriel
 */
/* *
 * Copyright 1993-2012 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 */
#include "NewLoop.h"
__managed__ int *posxREC = NULL;
__managed__ int *PosxScratch = NULL, *PosyScratch = NULL;
__managed__ int *offsetFULL = NULL;

void readstoreLaserPositions(void) {
	XMLDocument XMLdoc, ACQXML;
	XMLElement *pRoot, *pParm;
	string sstr;
	int index, numberofimages, offsetimages = 0;
	float maxLaserx = 0.0, minLaserx = 1E6, maxLasery = 0.0, minLasery = 1E6;

	filename = resourcesdirectory + "reconst_preprocess_results.xml";
	printf(" Laser \u2462  Laser positions:  %s \n", filename.c_str());
	int LoadOK = XMLError(XMLdoc.LoadFile(filename.c_str()));
	TA.Nb_LaserPositions = 0;

	if (!LoadOK) {
		if (verbose)
			std::cout << "reconst_preprocess_results.xml" << std::endl;
		pRoot = XMLdoc.FirstChildElement("Reconstruction_Preproc_Results");
		if (pRoot) {
			// Parse parameters
			pParm = pRoot->FirstChildElement("Laser_Positions")->FirstChildElement("Distrib");
			while (pParm) {
				index = atoi(pParm->Attribute("index"));
				numberofimages = atoi(pParm->Attribute("length"));
				Ndistrib = index + 1;
				TA.Images_perdistrib[index] = numberofimages;
				TA.Nb_LaserPositions += numberofimages;
				printf(" Laser \u2462 Distrib %d numberofimages %d ...  \n", index, numberofimages);
				pParm = pParm->NextSiblingElement("Distrib");
			}
		}
	}
	printf(" Laser \u2462 number of distrib %d ... ", Ndistrib);
	printf("TA.Nb_LaserPositions %d \n", TA.Nb_LaserPositions);

	cudaMallocManaged(&PosLaserx, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&PosLasery, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&d_PosLaserx, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&d_PosLasery, TA.Nb_LaserPositions * sizeof(float));

	/** Allocation of memory of intermediate values - for test and validation
	 *
	 */
	cudaMallocManaged(&PosxScratch, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&PosyScratch, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&offsetFULL, TA.Nb_LaserPositions * sizeof(int));

	if (!LoadOK) {
		if (pRoot) {
			// Parse parameters
			pParm = pRoot->FirstChildElement("Laser_Positions")->FirstChildElement("Distrib");
			while (pParm) {
				index = atoi(pParm->Attribute("index"));
				numberofimages = atoi(pParm->Attribute("length"));
				tile.Nblaserperdistribution[index] = numberofimages;
				sstr = pParm->GetText();
				for (unsigned int i = 0; i < strlen(chars); ++i)
					sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]), sstr.end());
				stringstream stream(sstr);
				if (verbose)
					std::cout << stream.str() << std::endl;
				for (int i = offsetimages; i < numberofimages + offsetimages; i++) {
					stream.getline(buff, 10, ',');
					// introduce here scale and offset relative to camera origin, if needed
					*(PosLaserx + i) = (atof(buff) + OFSCAL.offsetLaserx) * OFSCAL.scaleLaserx;
					maxLaserx = max(maxLaserx, *(PosLaserx + i));
					minLaserx = min(minLaserx, *(PosLaserx + i));
					if (verbose && (!(i % 2048)))
						printf(" Laser \u2462 i= %d buffer x %s %f\n", i, buff, *(PosLaserx + i));
					// Laser positions in x rounded in rec pixels
					int posxREC = std::round(pZOOM * *(PosLaserx + i));
					// Laser positions in x zoomed integer in the 2D scratchpad
					*(PosxScratch + i) = 33; //(posxREC % XTile) + dxSCR/2;

					stream.getline(buff, 10, ',');
					// introduce here scale and offset relative to camera origin, if needed
					*(PosLasery + i) = (atof(buff) + OFSCAL.offsetLasery) * OFSCAL.scaleLasery;
					maxLasery = max(maxLasery, *(PosLasery + i));
					minLasery = min(minLasery, *(PosLasery + i));
					if (verbose && (!(i % 2048)))
						printf(" Laser \u2462 i= %d buffer x %s %f\n", i, buff, *(PosLasery + i));

					// Laser positions in y zoomed in integer
					int posyREC = std::round(pZOOM * *(PosLasery + i));
					// Laser positions in y zoomed integer in the scratchpad
					*(PosyScratch + i) = 47; //(posyREC % YTile) + dySCR/2;

					*(offsetFULL + i) = *(PosyScratch + i) * XSCRATCH + *(PosxScratch + i) + lostpixels;
				}
				pParm = pParm->NextSiblingElement("Distrib");
				offsetimages += numberofimages;
			}
		}
	}
	printf(" Laser \u2462 min and max x %g %g, min and max y %g %g ... ", maxLaserx, minLaserx, maxLasery, minLasery);
	TA.maxLaserx = maxLaserx;
	TA.maxLasery = maxLasery;
	TA.minLaserx = minLaserx;
	TA.minLasery = minLasery;
	printf("number of distrib %d\n", Ndistrib);

	if (TA.Nb_LaserPositions < smallnumber)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			printf(" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
			printf(" Laser \u2462 Laser position %d  Laser position x: %f  y: %f\n", ival, *(PosLaserx + ival), *(PosLasery + ival));
			printf(" Laser \u2462 Position in scratchpad x: %d y: %d \n", *(PosxScratch + ival), *(PosyScratch + ival));
			printf(" Laser \u2462 ***************SCRATCHPAD FULL OFFSET %d **************\n",*(offsetFULL+ival));
			printf(" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
		}
}

bool validateLaserPositions_control(void) {

	double Delx { 0.0 }, Dely { 0.0 };
	bool testLaserPosition = FALSE;
	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Laser positions kernel
	validateLaserPositions_device<<<dimGrid, dimBlock, 0>>>(TA.Nb_LaserPositions);
	cudaDeviceSynchronize();

	for (int iLaser = 0; iLaser < TA.Nb_LaserPositions; iLaser++) {
		Delx += PosLaserx[iLaser] - d_PosLaserx[iLaser];
		Dely += PosLasery[iLaser] - d_PosLasery[iLaser];
	}
	Sumdel[2] = sqrt(Delx * Delx + Dely * Dely);
	printf(" Laser \u2462 delx %g dely %g Sumdel[2] %g \n", Delx, Dely, Sumdel[2]);
	if (Delx * Dely == 0.0f)
		testLaserPosition = TRUE;
	return (testLaserPosition);
}

void readstoreCroppedROI(void) {
	XMLDocument XMLdoc;
	XMLElement *pRoot, *pParm;
	string sstr;
	int numberofimages, offsetimages = 0, missedpoints = 0;
	XMLDocument doc;

	filename = resourcesdirectory + "reconst_preprocess_results.xml";
	printf(" ROI \u2463 ROI positions:  %s \n", filename.c_str());
	int LoadOK = XMLError(XMLdoc.LoadFile(filename.c_str()));

	cudaMallocManaged(&ROIx, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&ROIy, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&d_ROIx, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&d_ROIy, TA.Nb_LaserPositions * sizeof(int));

	if (!LoadOK) {
		pRoot = XMLdoc.FirstChildElement("Reconstruction_Preproc_Results");
		if (pRoot) {
			// Parse parameters
			pParm = pRoot->FirstChildElement("Measurement_AOIs")->FirstChildElement("Distrib");
			while (pParm) {
				numberofimages = atoi(pParm->Attribute("length"));
				missedpoints = 0;
				printf(" ROI \u2463 number of images %d \n", numberofimages);
				sstr = pParm->GetText();
				for (unsigned int i = 0; i < strlen(chars); ++i)
					sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]), sstr.end());
				stringstream stream(sstr);
				for (int i = offsetimages; i < offsetimages + numberofimages; i++) {
					stream.getline(buff, 10, ',');
					int temp = atoi(buff);
					*(ROIx + i) = temp;
					stream.getline(buff, 10, ',');
					temp = atoi(buff);
					*(ROIy + i) = temp;
					stream.getline(buff, 10, ','); // size of window in x constant
					temp = atoi(buff);
					stream.getline(buff, 10, ','); // size of window in y constant
					temp = atoi(buff);
					if (verbose && (!(i % 512)))
						printf(" ROI \u2463 i= %d ROI [%d,%d]\n", i, *(ROIx + i), *(ROIy + i));
					if (verbose && (*(ROIx + i) == 0) && (*(ROIy + i) == 0))
						missedpoints++;
					if (verbose && (*(ROIx + i) == 0) && (*(ROIy + i) == 0) && (!(i % 16)))
						printf(" ROI \u2463 i= %d, ", i);
				}
				if (missedpoints)
					printf(" ROI \u2463 \n missed points %d", missedpoints);

				pParm = pParm->NextSiblingElement("Distrib");
				offsetimages += numberofimages;
			}
		}
	}
	TA.maxROIx = 0;
	TA.maxROIy = 0;
	TA.minROIx = 512 * 512;
	TA.minROIy = 512 * 512;

	for (int i = 0; i < TA.Nb_LaserPositions; i++) {
		if (*(ROIx + i) > TA.maxROIx)
			TA.maxROIx = *(ROIx + i);
		if (*(ROIy + i) > TA.maxROIy)
			TA.maxROIy = *(ROIy + i);
		if (*(ROIx + i) < TA.minROIx)
			TA.minROIx = *(ROIx + i);
		if (*(ROIy + i) < TA.minROIy)
			TA.minROIy = *(ROIy + i);
	}
	printf(" ROI \u2463 min and max ROI x: min %d max %d y: min %d max %d\n", TA.minROIx, TA.maxROIx, TA.minROIy, TA.maxROIy);
	if (TA.Nb_LaserPositions < smallnumber)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			printf(" ROI \u2463 ---------------------------------------------------------------------\n");
			printf(" ROI \u2463 ROI position %d  ROI x: %d  y: %d\n", ival, *(ROIx + ival), *(ROIy + ival));
			printf(" ROI \u2463 ---------------------------------------------------------------------\n");
		}

}

bool validateCroppedROI_control(void) {

	double Delx, Dely;
	bool testROI = FALSE;
	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Laser positions kernel
	validateCroppedROI_device<<<dimGrid, dimBlock, 0>>>(TA.Nb_LaserPositions);
	cudaDeviceSynchronize();
	for (int iLaser = 0; iLaser < TA.Nb_LaserPositions; iLaser++) {
		Delx += ROIx[iLaser] - d_ROIx[iLaser];
		Dely += ROIy[iLaser] - d_ROIy[iLaser];
	}
	Sumdel[3] = Delx * Dely;
	if (Delx * Dely == 0.0f)
		testROI = TRUE;
	return (testROI);
}

