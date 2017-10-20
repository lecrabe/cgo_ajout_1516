####################################################################################################
####################################################################################################
## Filtrer FACET UMD CNIAF 2000 2014 a 5 pixel ~ 0.5 ha
## Contact remi.dannunzio@fao.org
## 2017/09/13
####################################################################################################
####################################################################################################
options(stringsAsFactors=FALSE)

library(Hmisc)
library(sp)
library(rgdal)
library(raster)
library(plyr)
library(foreign)


#######################################################################
##############################     SETUP YOUR DATA 
#######################################################################

## Set your working directory
setwd("~/cgo_ajout_1516/")
dir.create("sieve_work")

################################################################################
## Clump FACET 2000-2014 UMD CNIAF (equivalent polygones mais en mode raster)
system(sprintf("oft-clump -i %s -o %s -um %s",
               "facet_2000_2014.tif",
               paste0("sieve_work/clump.tif"),
               "facet_2000_2014.tif"))

####################################################################################################################
## Extraire valeurs du raster sur tous les segments
system(sprintf("oft-stat -i %s -o %s -um %s -nostd",
               "facet_2000_2014.tif",
               paste0("sieve_work/clump_val.txt"),
               paste0("sieve_work/clump.tif")
               ))

####################################################################################################################
## Lire le fichier des valeurs pour manipulation / filtrage intelligent
df <- read.table(paste0("sieve_work/clump_val.txt"))
names(df) <- c("id","size","class")

df$new <- df$class
df[df$class > 8 & df$size < 5,]$new <- df[df$class > 8 & df$size < 5,]$class - 8

table(df$class)
table(df$new)

####################################################################################################################
## Exporter la table des nouvelles valeurs
write.table(file=paste0("sieve_work/reclass.txt"),
            df[,c("id","new")],
            sep=" ",
            quote=FALSE, 
            col.names=FALSE,
            row.names=FALSE)


########################################
## Reclassifier le raster
system(sprintf("(echo %s; echo 1; echo 1; echo 2; echo 0) | oft-reclass -oi  %s %s",
               paste0("sieve_work/reclass.txt"),
               paste0("sieve_work/reclass.tif"),
               paste0("sieve_work/clump.tif")
               ))

########################################
## Compresser et projeter en UTM
system(sprintf("gdalwarp -t_srs EPSG:32733 -ot byte -overwrite -co COMPRESS=LZW %s %s",
               paste0("sieve_work/reclass.tif"),
               paste0("facet_2000_2014_filtrage5.tif")
))

system(sprintf("gdalwarp -t_srs EPSG:32733 -ot byte -overwrite -co COMPRESS=LZW %s %s",
               paste0("facet_2000_2014.tif"),
               paste0("facet_2000_2014_utm.tif")
))

####################################################################################################################
## Calculer l'histograme pour filtre et non filtre
system(sprintf("oft-zonal_large_list.py -i %s -um %s -o %s -a %s",
               paste0("facet_2000_2014_filtr5_utm.tif"),
               "limites_pays_officielles/DEPARTEMENTS_UTM33S.shp",
               paste0("stats_facet_0014_filtre_dpt.txt"),
               "CDE_PR_FEC"
               ))

system(sprintf("oft-zonal_large_list.py -i %s -um %s -o %s -a %s",
               paste0("facet_2000_2014_utm.tif"),
               "limites_pays_officielles/DEPARTEMENTS_UTM33S.shp",
               paste0("stats_facet_0014_dpt.txt"),
               "CDE_PR_FEC"
))

classes <- c("Foret primaire sur terre ferme",
             "Foret secondaire sur terre ferme",
             "Plantations forestieres",
             "Foret primaire marecageuse",
             "Forest secondaire marecageuse",
             "Autre marecages",
             "Non-Foret",
             "Eau",
             "Pertes en foret primaire sur terre ferme",
             "Pertes en foret secondaire sur terre ferme",
             "Pertes en foret primaire marecageuse",
             "Pertes en foret secondaire marecageuse",
             "Pertes en Plantations forestieres",
             "Pertes en autre marecage")
code <- read.dbf("../limites_pays_officielles/DEPARTEMENTS_UTM33S.dbf")
pix<- res(raster("facet_2000_2014_filtrage5.tif"))[1]


######################### Statistiques pour le produit filtre
df <- read.table("stats_facet_0014_filtre_dpt.txt")
names(df) <- c("dpt","total","no_data",classes)
df <- merge(df,code[c("CDE_PR_FEC","NOM_PR_FEC")],by.x="dpt",by.y="CDE_PR_FEC")
df[,2:17] <- df[,2:17]*pix*pix/10000
out <- df[,c(18,1,2:17)]
write.csv(out,"hist_sieve5_dpt.csv",row.names = F)

######################### Statistiques pour le produit non-filtre
df <- read.table("stats_facet_0014_dpt.txt")
names(df) <- c("dpt","total","no_data",classes)
df <- merge(df,code[c("CDE_PR_FEC","NOM_PR_FEC")],by.x="dpt",by.y="CDE_PR_FEC")
df[,2:17] <- df[,2:17]*pix*pix/10000
out <- df[,c(18,1,2:17)]
write.csv(out,"hist_facet_dpt.csv",row.names = F)
