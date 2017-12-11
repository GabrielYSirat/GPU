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
#include "0_Mainparameters.h"
ifstream ROIfile;
std::string ROIFILE = "lambda_488/Measure/T_0/Z_0/meas_ROIs_";
std::string endROI = ".txt";
int maxROIx = 0.0, minROIx = 1E6, maxROIy = 0.0, minROIy = 1E6;

void readstoreCroppedROI(void) {
	float ROIval;
	bool XY = FALSE;


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
		verbosefile << "filename " << filename.c_str() << " \n";
		ROIfile.open(filename);
		if (!ROIfile) {
			printf("unable to open filename %s\n\n", filename.c_str());
			exit(1);   // call system to stop
		}
		XY = FALSE;
		// introduce here scale and offset relative to camera origin, if needed
		while (ROIfile >> ROIval) {
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
		ROIfile.close();
	}

	verbosefile << "ROI \u2463 min and max x " << TA.maxROIx << " " << TA.minROIx << " y "
			<<  TA.maxROIy << " " << TA.minROIy << endl;
}

bool validateCroppedROI_control(void) {

	double Delx, Dely;
	bool testROI = FALSE;
	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Laser positions kernel
	validateCroppedROI_device<<<dimGrid, dimBlock, 0>>>(TA.Nb_LaserPositions);
	cudaDeviceSynchronize();

	if (TA.Nb_LaserPositions < SPARSE && VERBOSE)
		for (int ival = 0; ival < TA.Nb_LaserPositions; ival++) {
			if(!ival)
			verbosefile <<" ROI \u2463 ----------------------------------------------------------------------------------------------------\n";
			verbosefile << " ROI \u2463 ROI position " << ival << " ROI position x & y: ";
			verbosefile << ival << "  " << *(ROIx + ival) << "  " << *(ROIy + ival) << endl;
			verbosefile << " ROI \u2463 ROI position in scratchpad " << ival << " ROI position x & y: ";
			verbosefile << ival << "  " << *(ROIxScratch + ival) << "  " << *(ROIyScratch + ival);
			verbosefile << ival << " ROI \u2463 ***************SCRATCHPAD FULL OFFSET ";
			verbosefile << ival << *(offsetROI + ival) << "*************\n";
			verbosefile << " ROI \u2463 --------------------------------------------------------------------------------------------------\n";
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

