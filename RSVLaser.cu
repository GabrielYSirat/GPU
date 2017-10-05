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
ifstream inFile;
std::string LaserFILE = "lambda_488/Measure/T_0/Z_0/laser_positions_";
std::string endlaser = ".txt";
std::string ROIFILE = "lambda_488/Measure/T_0/Z_0/meas_ROIs_";
std::string endROI = ".txt";
int maxROIx = 0.0, minROIx = 1E6, maxROIy = 0.0, minROIy = 1E6;
bool XY = FALSE;

void readstoreLaserPositions(void) {
	float laserval;

	TA.Nb_LaserPositions = 0;
	tile.maxlaserperdistribution = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
	{
		filename = resourcesdirectory + LaserFILE + std::to_string(idistrib + 1) + endlaser;
		inFile.open(filename);
		if (!inFile) {
			printf("unable to open filename %s\n\n", filename.c_str());
			exit(1);   // call system to stop
		}

		tile.Nblaserperdistribution[idistrib] = 0;
		while (inFile >> laserval) {
			if (XY) {
				TA.Nb_LaserPositions++; tile.Nblaserperdistribution[idistrib]++; }
			XY = !XY;
		} // adding one at the end because it is a number of positions

		tile.maxlaserperdistribution = max(tile.maxlaserperdistribution, tile.Nblaserperdistribution[idistrib]);
		printf(" Laser \u2462: distribution n°%d number of images %d   ", idistrib, tile.Nblaserperdistribution[idistrib]);

		inFile.close();
	}
	printf(" total number of images %d max images per distributions %d \n",  TA.Nb_LaserPositions, tile.maxlaserperdistribution);

	cudaMallocManaged(&PosLaserx, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&PosLasery, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&d_PosLaserx, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&d_PosLasery, TA.Nb_LaserPositions * sizeof(float));
	cudaMallocManaged(&PosxScratch, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&PosyScratch, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&offsetFULL, TA.Nb_LaserPositions * sizeof(int));

	int ilaserpos = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		filename = resourcesdirectory + LaserFILE + std::to_string(idistrib + 1) + endlaser;
		printf("Laser \u2462: filename %s \n", filename.c_str());
		inFile.open(filename);
		if (!inFile) {
			printf("unable to open filename %s\n\n", filename.c_str());
			exit(1);   // call system to stop
		}
		XY = FALSE;
		// introduce here scale and offset relative to camera origin, if needed
		while (inFile >> laserval) {
			if (!XY) {
			*(PosLaserx + ilaserpos) = (laserval + OFSCAL.offsetLaserx)* OFSCAL.scaleLaserx;
			TA.maxLaserx = max(TA.maxLaserx, *(PosLaserx + ilaserpos));
			TA.minLaserx = min(TA.minLaserx, *(PosLaserx + ilaserpos));
			// Laser positions in x zoomed integer in the 2D scratchpad
			}
			else {
				*(PosLasery + ilaserpos) = (laserval + OFSCAL.offsetLasery) * OFSCAL.scaleLasery;
				TA.maxLasery = max(TA.maxLasery, *(PosLasery + ilaserpos));
				TA.minLasery = min(TA.minLasery, *(PosLasery + ilaserpos));
				ilaserpos++;
			}
			XY = !XY;
		}
		inFile.close();
	}

	printf(" Laser \u2462 min and max x %g %g, min and max y %g %g ... \n",
			TA.maxLaserx, TA.minLaserx, TA.maxLasery, TA.minLasery);
}

bool validateLaserPositions_control(void) {

	double Delx { 0.0 }, Dely { 0.0 };
	bool testLaserPosition = FALSE;
	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Laser positions kernel
	validateLaserPositions_device<<<dimGrid, dimBlock, 0>>> (TA.Nb_LaserPositions);
	cudaDeviceSynchronize();

	if (TA.Nb_LaserPositions < smallnumber)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			if(!ival) printf(" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
			printf(" Laser \u2462 Laser position %d  Laser position x: %f  y: %f\n",
					ival, *(PosLaserx + ival), *(PosLasery + ival));
			printf(" Laser \u2462 Position in scratchpad x: %d y: %d \n",
					*(PosxScratch + ival), *(PosyScratch + ival));
			printf(" Laser \u2462 ***************SCRATCHPAD FULL OFFSET %d **************\n",
					*(offsetFULL + ival));
			printf(" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
		}
	printf(" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
	for (int iLaser = 0; iLaser < TA.Nb_LaserPositions; iLaser++) {
		Delx += PosLaserx[iLaser] - d_PosLaserx[iLaser];
		Dely += PosLasery[iLaser] - d_PosLasery[iLaser];
	}
	Sumdel[2] = sqrt(Delx * Delx + Dely * Dely);
	printf(" Laser \u2462 delx %8.6f dely %8.6f Sumdel[2] %8.6f \n", Delx, Dely, Sumdel[2]);
	if (Delx * Dely == 0.0f) testLaserPosition = TRUE;

	return (testLaserPosition);
}

void readstoreCroppedROI(void) {
	float ROIval;

	cudaMallocManaged(&ROIx, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&ROIy, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&d_ROIx, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&d_ROIy, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&ROIxScratch, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&ROIyScratch, TA.Nb_LaserPositions * sizeof(int));
	cudaMallocManaged(&offsetROI, TA.Nb_LaserPositions * sizeof(int));

	int iROIpos = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		filename = resourcesdirectory + ROIFILE + std::to_string(idistrib + 1) + endROI;
		printf("filename %s \n", filename.c_str());
		inFile.open(filename);
		if (!inFile) {
			printf("unable to open filename %s\n\n", filename.c_str());
			exit(1);   // call system to stop
		}
		XY = FALSE;
		// introduce here scale and offset relative to camera origin, if needed
		while (inFile >> ROIval) {
			if (!XY) {
			*(ROIx + iROIpos) = (ROIval + OFSCAL.offsetROIx)* OFSCAL.scaleROIx;
			TA.maxROIx = max(TA.maxROIx, *(ROIx + iROIpos));
			TA.minROIx = min(TA.minROIx, *(ROIx + iROIpos));
			// Laser positions in x zoomed integer in the 2D scratchpad
			}
			else {
				*(ROIy + iROIpos) = (ROIval + OFSCAL.offsetROIy) * OFSCAL.scaleROIy;
				TA.maxROIy = max(TA.maxROIy, *(ROIy + iROIpos));
				TA.minROIy = min(TA.minROIy, *(ROIy + iROIpos));
				iROIpos++;
			}
			XY = !XY;
		}
		inFile.close();
	}

	printf(" ROI \u2463 min and max x %d %d, min and max y %d %d ... ",
			TA.maxROIx, TA.minROIx, TA.maxROIy, TA.minROIy);
}

bool validateCroppedROI_control(void) {

	double Delx, Dely;
	bool testROI = FALSE;
	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Laser positions kernel
	validateCroppedROI_device<<<dimGrid, dimBlock, 0>>>(TA.Nb_LaserPositions);
	cudaDeviceSynchronize();

	if (TA.Nb_LaserPositions < smallnumber)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			if(!ival) printf(" ROI \u2463 ----------------------------------------------------------------------------------------------------\n");
			printf(" ROI \u2463 ROI position %d  ROI position x: %d  y: %d\n",
					ival, *(ROIx + ival), *(ROIy + ival));
			printf(" ROI \u2463 Position in scratchpad x: %d y: %d \n",
					*(ROIxScratch + ival), *(ROIyScratch + ival));
			printf(" ROI \u2463 ***************SCRATCHPAD FULL OFFSET %d **************\n",
					*(offsetROI + ival));
			printf(" ROI \u2463 ----------------------------------------------------------------------------------------------------\n");
		}

	for (int iROI = 0; iROI < TA.Nb_LaserPositions; iROI++) {
		Delx += ROIx[iROI] - d_ROIx[iROI];
		Dely += ROIy[iROI] - d_ROIy[iROI];
	}
	Sumdel[3] = Delx * Dely;
	if (Delx * Dely == 0.0f)
		testROI = TRUE;
	return (testROI);
}

