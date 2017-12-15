/*
 * MainGPU.cu
 *
 *  Created on: June 5, 2017
 *      Author: gabriel Sirat
 */

#include "0_Mainparameters.h"
#include <iostream>
#include <fstream>
ofstream verbosefile;

/************* Classes and structures*******/
GPU_init TA;
COS OFSCAL;
Ctile tile;
devicedata onhost;
int clockRate, devID, stepval = 0; // in KHz
float MaxData_main;


////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv) {


	verbosefile.open ("results/Z_verbosefile.txt");



}

