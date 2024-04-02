# gssim
GelSight measurement simulations for algorithm development and verification.

## Description 

This project contains MATLAB code for generating simulated GelSight scans that can be loaded into GelSight commercial software, GelSight Mobile and GSCapture, for testing measurement routines. The functions can create scans with known heightmaps (Z), sets of simulated images, along with a scan.yaml file within a scan folder. The scan folder can be added to an active library and analyzed by GelSight software.

## Prerequisites

This software is written in MATLAB and assumes the [gsmatlab](https://github.com/gelsightinc/gsmatlab) package is in your MATLAB path.

You will also need to compile the shadeQuadratic.cpp file using mex. 
```
>> mex shadeQuadratic.cpp
```

## Devices

Calibration files for different GelSight devices. Calibration files from other
devices can be added to this folder. Be careful when renaming the files - the
name of the png file is stored in a field towards the bottom of the yaml file.
If it is renamed, the string in this field should be changed:
```
flatfield: 
    modelfile: series2_2EF6_4JNW.png  <-- this name must match the png file name
    modelsize: (616, 514)
```

## Example Usage

### Create a scan using default parameters
Create a simulated groove scan using a Series2 calibration and save the result
in a scan folder named Scan:
```
>> createscan('series2_2EF6_4JNW', 'groove', 'Scan');
```


