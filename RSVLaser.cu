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
std::string LaserFILE = "lambda_488/Measure/T_0/Z_0/laser_positions_";
std::string endlaser = ".txt";
float maxLaserx = 0.0, minLaserx = 1E6, maxLasery = 0.0, minLasery = 1E6;


void readstoreLaserPositions(void) {
	XMLDocument XMLdoc, ACQXML;
	ifstream inFile;
	string sstr;
	float laserval;
	bool XY = FALSE;
	int numberofimages;
	int xREC, yREC;

	TA.Nb_LaserPositions = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		filename = resourcesdirectory + LaserFILE + std::to_string(idistrib + 1) + endlaser;
		printf("Laser \u2462 idistrib %d filename %s \n", idistrib, filename.c_str());
		inFile.open(filename);
		if (!inFile) {
			printf("unable to open filename %s\n\n", filename.c_str());
			exit(1);   // call system to stop
		}
		numberofimages = 0;
		while (inFile >> laserval) {
			if (XY) {
				TA.Nb_LaserPositions++; numberofimages++; }
			if (!verbose)
			XY = !XY;
		} // adding one at the end because it is a number of positions
		tile.Nblaserperdistribution[idistrib] = numberofimages;
		printf(" Laser \u2462: distribution n°%d number of images %d\n", idistrib, tile.Nblaserperdistribution[idistrib]);

		inFile.close();
	}
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
		printf("filename %s \n", filename.c_str());
		inFile.open(filename);
		if (!inFile) {
			printf("unable to open filename %s\n\n", filename.c_str());
			exit(1);   // call system to stop
		}
		XY = FALSE;
		// introduce here scale and offset relative to camera origin, if needed
		while (inFile >> laserval) {
//			printf("laserval %g, XY %d, il %d\n", laserval, XY, ilaserpos);
			if (!XY) {
			*(PosLaserx + ilaserpos) = (laserval + OFSCAL.offsetLaserx)* OFSCAL.scaleLaserx;
			maxLaserx = max(maxLaserx, *(PosLaserx + ilaserpos));
			minLaserx = min(minLaserx, *(PosLaserx + ilaserpos));
			xREC = std::round(pZOOM * *(PosLaserx + ilaserpos));
			// Laser positions in x zoomed integer in the 2D scratchpad
			*(PosxScratch + ilaserpos) = (xREC % XTile) + dxSCR/2;
// 		printf("xREC %d scratch %d\n", xREC, *(PosxScratch + ilaserpos));
			}
			else {
				*(PosLasery + ilaserpos) = (laserval + OFSCAL.offsetLasery) * OFSCAL.scaleLasery;
				maxLasery = max(maxLasery, *(PosLasery + ilaserpos));
				minLasery = min(minLasery, *(PosLasery + ilaserpos));
				// Laser positions in y zoomed in integer
				yREC = std::round(pZOOM * *(PosLasery + ilaserpos));
				// Laser positions in y zoomed integer in the scratchpad
				*(PosyScratch + ilaserpos) = (yREC % YTile) + dySCR/2;
				*(offsetFULL + ilaserpos) = *(PosyScratch + ilaserpos) * XSCRATCH + *(PosxScratch + ilaserpos) + lostpixels;
//				printf("yREC %d y scratch %d offsetFull %d\n", yREC, *(PosyScratch + ilaserpos), *(offsetFULL + ilaserpos));
//				printf("laserval %g, XY %d, il %d rec x:%d y:%d val %g scratch %d\n",
//						laserval, XY, ilaserpos, xREC, yREC, *(PosLaserx + ilaserpos),
//						*(PosxScratch + ilaserpos));
				ilaserpos++;
			}
			XY = !XY;
		}
		inFile.close();
	}
	printf(" Laser \u2462: TA.Nb_LaserPositions %d \n", TA.Nb_LaserPositions);

	/** Allocation of memory of intermediate values - for test and validation
	 *
	 */

	printf(" Laser \u2462 min and max x %g %g, min and max y %g %g ... ",
			maxLaserx, minLaserx, maxLasery, minLasery);
	TA.maxLaserx = maxLaserx;
	TA.maxLasery = maxLasery;
	TA.minLaserx = minLaserx;
	TA.minLasery = minLasery;
	printf("number of distrib %d\n", Ndistrib);

	if (TA.Nb_LaserPositions < smallnumber)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			printf(
					" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
			printf(
					" Laser \u2462 Laser position %d  Laser position x: %f  y: %f\n",
					ival, *(PosLaserx + ival), *(PosLasery + ival));
			printf(" Laser \u2462 Position in scratchpad x: %d y: %d \n",
					*(PosxScratch + ival), *(PosyScratch + ival));
			printf(
					" Laser \u2462 ***************SCRATCHPAD FULL OFFSET %d **************\n",
					*(offsetFULL + ival));
			printf(
					" Laser \u2462 ----------------------------------------------------------------------------------------------------\n");
		}
}

bool validateLaserPositions_control(void) {

	double Delx { 0.0 }, Dely { 0.0 };
	bool testLaserPosition = FALSE;
	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Laser positions kernel
	validateLaserPositions_device<<<dimGrid, dimBlock, 0>>>(
			TA.Nb_LaserPositions);
	cudaDeviceSynchronize();

	for (int iLaser = 0; iLaser < TA.Nb_LaserPositions; iLaser++) {
		Delx += PosLaserx[iLaser] - d_PosLaserx[iLaser];
		Dely += PosLasery[iLaser] - d_PosLasery[iLaser];
	}
	Sumdel[2] = sqrt(Delx * Delx + Dely * Dely);
	printf(" Laser \u2462 delx %g dely %g Sumdel[2] %g \n", Delx, Dely,
			Sumdel[2]);
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
			pParm =
					pRoot->FirstChildElement("Measurement_AOIs")->FirstChildElement(
							"Distrib");
			while (pParm) {
				numberofimages = atoi(pParm->Attribute("length"));
				missedpoints = 0;
				printf(" ROI \u2463 number of images %d \n", numberofimages);
				sstr = pParm->GetText();
				for (unsigned int i = 0; i < strlen(chars); ++i)
					sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]),
							sstr.end());
				stringstream stream(sstr);
				for (int i = offsetimages; i < offsetimages + numberofimages;
						i++) {
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
						printf(" ROI \u2463 i= %d ROI [%d,%d]\n", i,
								*(ROIx + i), *(ROIy + i));
					if (verbose && (*(ROIx + i) == 0) && (*(ROIy + i) == 0))
						missedpoints++;
					if (verbose && (*(ROIx + i) == 0) && (*(ROIy + i) == 0)
							&& (!(i % 16)))
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
	printf(" ROI \u2463 min and max ROI x: min %d max %d y: min %d max %d\n",
			TA.minROIx, TA.maxROIx, TA.minROIy, TA.maxROIy);
	if (TA.Nb_LaserPositions < smallnumber)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			printf(
					" ROI \u2463 ---------------------------------------------------------------------\n");
			printf(" ROI \u2463 ROI position %d  ROI x: %d  y: %d\n", ival,
					*(ROIx + ival), *(ROIy + ival));
			printf(
					" ROI \u2463 ---------------------------------------------------------------------\n");
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

