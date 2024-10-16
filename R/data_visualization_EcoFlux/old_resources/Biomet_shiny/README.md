# UBC Micro-/Biometeorology Flux Visualization
An RShiny app to visualize Flux data, based on the Ameriflux app developed Sophie Ruehr at UC Berkeley (see acknowledgements for contact information).

## About this visualization tool
This app was developed to allow user-uploaded flux data to be visualized through a variety of plots: Time Series, Diurnal, Scatter/Density, Radiation, Missing and Summary Statistics.

Currently hosted locally, so to run this app, you will need to first download the `app_BioMet.R` file onto your desktop. Once it is downloaded locally, install any packages that are missing, and then the app should open up. 

Once open, the user is able to upload flux stage data (downloaded as .csv's or else an error will be generated) within the `App Description` section, where you can either upload the sole second stage data, as all plots will work with just that one upload, or you can add in additional third stage data. Multiple files may be uploaded in either upload section, but they must all be selected at one time (If you drag a new .csv file over a previously uploaded one it will be replaced not attached).

Once uploaded the user can select whichever visualization type they would like, and within each tab, there are unique selection options, but mainly the user will select their variable of interest, along with what stage they would like it to be shown for (if both stage's have data inputted), and the plot will be displayed. A more extensive description, giving a run down of each tab's function can be found within `app_BioMet.R` file, as well as on ubc-micromet.github.io (?).

## Acknowledgements
A special thanks to Dr. Sara Knox, and other members of the UBC Micrometeorology Lab, who provided guidance, and codes, throughout the creation of this app.

AmeriFlux Data Visualization Tool, Sophie Ruehr (2022), 10.5281/zenodo.7023749.
