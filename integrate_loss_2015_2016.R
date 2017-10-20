####################################################################################################
####################################################################################################
## Intégrer les pertes 2015 2016 dans le produit CNIAF UMD 2000-2014, pertes filtrées à 5 pixels 
## remi.dannunzio@fao.org
## 2017/10/20
####################################################################################################
####################################################################################################
options(stringsAsFactors=FALSE)

library(Hmisc)
library(sp)
library(rgdal)
library(raster)
library(plyr)
library(foreign)
library(rgeos)


###########################################################################################
##############################     SETUP YOUR DATA 
###########################################################################################

## Repertoire de travail
setwd("~/cgo_ajout_1516/")

## Telecharger les donnees
system("wget https://www.dropbox.com/s/62ejfzw6v5fenry/ajout_perte1516.zip?dl=0")
system("unzip ajout_perte1516.zip?dl=0" )



shp_perte_2016 <- readOGR("terra_mayombe/pertes_2016/PERTES_DEBOISEMENT_pol.shp","PERTES_DEBOISEMENT_pol")
shp_route_2016 <- readOGR("terra_mayombe/pertes_2016/ROUTES_DEBOISEES_pol.shp","ROUTES_DEBOISEES_pol")
shp_perte_2015 <- readOGR("terra_mayombe/pertes_2015/dsf2015_clip_pol.shp","dsf2015_clip_pol")

shp_route_2016@data$code <- 16
shp_perte_2016@data$code <- 16
shp_perte_2015@data$code <- 15

prj_utm <- proj4string(raster("facet_2000_2014_filtrage5.tif"))
utm_route_2016 <- spTransform(shp_route_2016,prj_utm)
utm_perte_2016 <- spTransform(shp_perte_2016,prj_utm)
utm_perte_2015 <- spTransform(shp_perte_2015,prj_utm)

utm_perte_2015@data$area_remi <- gArea(utm_perte_2015,byid = T)
utm_perte_2016@data$area_remi <- gArea(utm_perte_2016,byid = T)
utm_route_2016@data$area_remi <- gArea(utm_route_2016,byid = T)

utm_perte_2015 <- utm_perte_2015[utm_perte_2015$area_remi > 5000,]
utm_perte_2016 <- utm_perte_2016[utm_perte_2016$area_remi > 5000,]
utm_route_2016 <- utm_route_2016[utm_route_2016$area_remi > 5000,]

writeOGR(utm_route_2016,"integrate_1516/utm_route_2016.shp","utm_route_2016","ESRI Shapefile",overwrite_layer = T)
writeOGR(utm_perte_2016,"integrate_1516/utm_perte_2016.shp","utm_perte_2016","ESRI Shapefile",overwrite_layer = T)
writeOGR(utm_perte_2015,"integrate_1516/utm_perte_2015.shp","utm_perte_2015","ESRI Shapefile",overwrite_layer = T)

##########################################################################################
## Rasteriser les routes 2016
system(sprintf("python oft-rasterize_attr.py -v %s -o %s -i %s -a %s",
               "integrate_1516/utm_route_2016.shp",
               "integrate_1516/utm_route_2016.tif",
               "facet_2000_2014_filtrage5.tif",
               "code"))

##########################################################################################
## Rasteriser les pertes 2016
system(sprintf("python oft-rasterize_attr.py -v %s -o %s -i %s -a %s",
               "integrate_1516/utm_perte_2016.shp",
               "integrate_1516/utm_perte_2016.tif",
               "facet_2000_2014_filtrage5.tif",
               "code"))

##########################################################################################
## Rasteriser les pertes 2015
system(sprintf("python oft-rasterize_attr.py -v %s -o %s -i %s -a %s",
               "integrate_1516/utm_perte_2015.shp",
               "integrate_1516/utm_perte_2015.tif",
               "facet_2000_2014_filtrage5.tif",
               "code"))

##########################################################################################
#### Ajouter les pertes 2015 sur la carte occupation des sols
system(sprintf("gdal_calc.py -A %s -B %s --type=Byte --NoDataValue=0 --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               "facet_2000_2014_filtrage5.tif",
               "integrate_1516/utm_perte_2015.tif",
               "integrate_1516/tmp_perte_2015.tif",
               "(B==0)*A+(B==15)*((A<7)*(A+8)+(A>6)*A)"
))

##########################################################################################
#### Ajouter les pertes 2016 sur la carte occupation des sols
system(sprintf("gdal_calc.py -A %s -B %s --type=Byte --NoDataValue=0 --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               "integrate_1516/tmp_perte_2015.tif",
               "integrate_1516/utm_perte_2016.tif",
               "integrate_1516/tmp_perte_2016.tif",
               "(B==0)*A+(B==16)*((A<7)*(A+8)+(A>6)*A)"
))

##########################################################################################
#### Ajouter les routes 2016 sur la carte occupation des sols
system(sprintf("gdal_calc.py -A %s -B %s --type=Byte --NoDataValue=0 --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               "integrate_1516/tmp_perte_2016.tif",
               "integrate_1516/utm_route_2016.tif",
               "integrate_1516/tmp_route_2016.tif",
               "(B==0)*A+(B==16)*((A<7)*(A+8)+(A>6)*A)"
))


##########################################################################################
####  GENERER UNE TABLE DE COULEURS
####  exemples en tapant : colors()
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

cols <- col2rgb(c("black",       #0 nodata
                  "darkgreen",   #1 FPTF
                  "green1",      #2 TSTF
                  "green2",      #3 PF
                  "green3",      #4 FPM
                  "green4",      #5 FSM
                  "chartreuse",  #6 AM
                  "grey",        #7 A
                  "darkblue",    #8 E
                  "red",         #9  PPTF
                  "red1",        #10 PSTF
                  "red2",        #11 PPF     
                  "red3",        #12 PFPM
                  "red4",        #13 PFSM  
                  "yellow"))     #14 PAM

pct <- data.frame(cbind(c(0,1:14),
                        cols[1,],
                        cols[2,],
                        cols[3,]
)
)

write.table(pct,"integrate_1516/color_table.txt",row.names = F,col.names = F,quote = F)

##########################################################################################
####  AJOUTER LA TABLE DE COULEURS
system(sprintf("(echo %s) | oft-addpct.py %s %s",
               "integrate_1516/color_table.txt",
               "integrate_1516/tmp_route_2016.tif",
               "integrate_1516/tmp_pct_route_2016.tif"
))

##########################################################################################
####  COMPRESSER
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               "integrate_1516/tmp_pct_route_2016.tif",
               "cniaf_2000_2016.tif"
))

##########################################################################################
####  PROJETER LES ANNEES DE PERTES EN UTM
system(sprintf("gdalwarp -t_srs EPSG:32733 -ot Byte -dstnodata none -overwrite -co COMPRESS=LZW %s %s",
               "facet_2000_2014_lossyear.tif",
               "facet_2000_2014_lossyear_utm.tif"
))

##########################################################################################
#### Ajouter les pertes 2015 sur les années de changement
system(sprintf("gdal_calc.py -A %s -B %s --type=Byte --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               "facet_2000_2014_lossyear_utm.tif",
               "integrate_1516/utm_perte_2015.tif",
               "integrate_1516/tmp_ly_perte_2015.tif",
               "(A==0)*B+(A>0)*A"
))

##########################################################################################
#### Ajouter les pertes 2016 sur les années de changement
system(sprintf("gdal_calc.py -A %s -B %s --type=Byte --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               "integrate_1516/tmp_ly_perte_2015.tif",
               "integrate_1516/utm_perte_2016.tif",
               "integrate_1516/tmp_ly_perte_2016.tif",
               "(A==0)*B+(A>0)*A"
))

##########################################################################################
#### Ajouter les routes 2016 sur les années de changement
system(sprintf("gdal_calc.py -A %s -B %s --type=Byte --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               "integrate_1516/tmp_ly_perte_2016.tif",
               "integrate_1516/utm_route_2016.tif",
               "integrate_1516/tmp_ly_route_2016.tif",
               "(A==0)*B+(A>0)*A"
))

##########################################################################################
#### Filtrage final (on reutilise la carte faite precedemment ou les pertes sont filtrees a 5 pixels)
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --NoDataValue=0 --type=Byte --outfile=%s --calc=\"%s\"",
               "integrate_1516/tmp_ly_route_2016.tif",
               "cniaf_2000_2016.tif",
               "integrate_1516/tmp_pertes_finales.tif",
               "(B==0)*0+(B>0)*(B<=6)*A+(B>6)*(B<=8)*0+(B>8)*A+(A>200)*0"
))

##########################################################################################
####  COMPRESSER
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               "integrate_1516/tmp_pertes_finales.tif",
               "cniaf_2000_2016_lossyear.tif"
))

# ##########################################################################################
# ## Calculer l'histograme des pertes
# system(sprintf("oft-zonal_large_list.py -i %s -um %s -o %s -a %s",
#                paste0("cniaf_2000_2016_lossyear.tif"),
#                "../limites_pays_officielles/DEPARTEMENTS_UTM33S.shp",
#                paste0("stats_cniaf_2000_2016.txt"),
#                "CDE_PR_FEC"
#                ))
# 
# code <- read.dbf("../limites_pays_officielles/DEPARTEMENTS_UTM33S.dbf")
# 
# ######################### Statistiques pour le produit filtre
# df <- read.table("stats_cniaf_2000_2016.txt")
# names(df) <- c("dpt","total","non_perte",paste0("perte_ha_20",1:16))
# summary(df)
# df <- merge(df,code[c("CDE_PR_FEC","NOM_PR_FEC")],by.x="dpt",by.y="CDE_PR_FEC")
# df[,2:19] <- df[,2:19]*pix*pix/10000
# out <- df[,c(20,1,2:19)]
# out
# write.csv(out,"stats_dpt_cniaf_2000_2016.csv",row.names = F)


