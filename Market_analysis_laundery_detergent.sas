
data groc;
infile 'H:\laundet\laundet_groc_1114_1165' firstobs=2 missover;
input IRI_KEY  WEEK SY  GE VEND ITEM UNITS DOLLARS F $ D PR;
run;

/*product description dataset*/
PROC IMPORT DATAFILE='H:\laundet\prod_laundet.xls' OUT = laun DBMS=xls replace;
RUN;

/* Renaming the Company and Brand column*/
data laun;
set laun (RENAME=(L5=Brand L3=Company));
run;

/* creating new column in grocery data for merging purpose*/
data laun_groc;
set groc;
upc_new=cats(of SY GE VEND ITEM);
run;
/* creating new column in product dataset for merging purpose*/
data laun_prod;
set laun;
upc_new=cats(of SY GE VEND ITEM) ;
run;

/* sorting grocery data*/
proc sort data=laun_groc;
by upc_new;
run;

/* sorting product  data*/
proc sort data=laun_prod;
by upc_new;
run;

/*merging grocery and prod data*/
data groc_prod;
merge laun_groc(IN=aa) laun_prod(DROP = SY GE VEND ITEM);
by upc_new;
if aa;
run;

/*proc export data= groc_prod
    outfile='H:\groc_prod_INIT.csv'
    dbms=csv
    replace;
run;*/

proc print data=groc_prod(obs=6);run;
data groc_prod_1;
set groc_prod;
if L2 = 'POWDER LAUNDRY DETERGENT';
run;
proc print data= groc_prod_1(obs =6);run;

/*proc export data= groc_prod_1
    outfile='H:\groc_prod_F.csv'
    dbms=csv
    replace;
run;*/

Libname cc "C:\Users\sxs180240\Desktop";
data cc.Laundery;
set groc_prod_1;
run;
/*q1:-1*What are the top 6 brands in the category in terms of dollar sales?
What are the market shares of the 6 brands (assuming there are only 6 brands in the market).*/


Title 'Top 5 Brands';
Proc means data = groc_prod_1 sum;
class Brand;
var Dollars;
output out = dollar_sale SUM = Sum_Of_Sales;
run;
proc sort data = dollar_sale;
by descending Sum_Of_Sales;
run;
proc print data=dollar_sale(obs=5);
where _Type_ = 1;
run;
data Top6;
set dollar_sale(obs=5);
where _Type_ = 1;
run;

proc sort data = Top6; by descending Sum_Of_Sales;run;
proc print data = Top6(drop = _TYPE_);
run;
Title 'Market Share of Top 5 Brands';
proc tabulate data = Top6;
 var Sum_Of_Sales;
  class Brand;
    table
    Brand
    all
    ,
    Sum_Of_Sales * colpctsum ;
	run;



data groc_prod_2;
set groc_prod_1;
if Brand in ('ARM & HAMMER FABRICARE','ARM & HAMMER') then brand='ARM&HAMMER';
else if Brand in ('CHEER') then brand='CHEER';
else if Brand in ('GAIN') then brand='GAIN';
else if Brand in ('SURF') then brand='SURF';
else if Brand in ('TIDE') then brand='TIDE';
else brand='Brand';
run;

data groc_prod_3; 
set groc_prod_2;
   length brand_final $29;
   format brand_final $29. ;
   informat brand_final $29.;
run;

data groc_prod_final;
set groc_prod_3;
if brand= 'ARM&HAMMER' then brand_final='ARM&HAMMER';
else if brand= 'CHEER' then brand_final='CHEER';
else if brand= 'GAIN' then brand_final='GAIN';
else if brand= 'SURF' then brand_final='SURF';
else if brand= 'TIDE' then brand_final='TIDE';
else brand_final='OTHER';
run;





/* PS I: Q:Fixed effect*/
/********************************************begin of Fixed Effect Code***************************************************************/

data groc_prod_FixedEffect;
set groc_prod_final;
run;

/*Market share for top seven brand in order*/
proc freq data=groc_prod_FixedEffect ORDER=FREQ; 
table brand_final;
run;

/* creating dummy variable for Column feature*/
DATA groc_prod_FixedEffect_F ;
set groc_prod_FixedEffect;
IF f = 'A+' THEN feat_coupon = 1; 
    ELSE feat_coupon = 0;
  IF f = 'A' THEN feat_large = 1; 
    ELSE feat_large = 0;
 IF f = 'B' THEN feat_medium = 1; 
    ELSE feat_medium = 0;
 IF f = 'C' THEN feat_small = 1; 
    ELSE feat_small = 0;	
 IF f = 'NONE' THEN feat_none = 1; 
    ELSE feat_none = 0;	
RUN;
/*Create PPU by formula ((dollars/units)/vol_eq)/16, Display, nd PR Dummy*/

proc printto log="C:\Users\sxs180240\Desktop\upc2_concat.log";
run;
data SB_AvgPPU_F_PR_D;
set groc_prod_FixedEffect_F;
AvgPPU = ((dollars/units)/vol_eq)/16;
if d = 0 then DISPLAY = 0;else DISPLAY = 1;
if PR = 1 then PriceRed = 1;else PriceRed = 0;
put DISPLAY PriceRed AvgPPU;
run;
proc printto;
run;
/* sorting data*/
proc sort data=SB_AvgPPU_F_PR_D;
by IRI_KEY WEEK;
run;
proc contents data=SB_AvgPPU_F_PR_D; run;
/*Checking missing data in Panel_demo file*/
proc means data=SB_AvgPPU_F_PR_D NMISS N; run;
/* there is no missing value*/

/* created a new table for calculating average of each varaible */
proc sql;
create table SB_AvgPPU_F_PR_D_edit as
SELECT IRI_KEY as IRI_KEY, WEEK as WEEK, sum(DOLLARS) as TotalSales_w, Avg(AvgPPU) as AvgPrice_w, Avg(DISPLAY)as AvgDisplay_w, Avg(feat_coupon)as AvgFeat_coupon_w, Avg(feat_large)as AvgFeat_large_w,
Avg(feat_medium)as AvgFeat_medium_w, Avg(feat_small)as AvgFeat_small_w, Avg(feat_none)as AvgFeat_none_w, Avg(PriceRed) as AvgPriceRed_w
FROM SB_AvgPPU_F_PR_D
WHERE Brand = 'ARM&HAMMER'
GROUP BY IRI_KEY,WEEK
ORDER BY IRI_KEY,WEEK; 
quit;
proc panel data=SB_AvgPPU_F_PR_D_edit plots =None;       
id IRI_KEY WEEK;       
model TotalSales_w=AvgPrice_w AvgDisplay_w AvgFeat_coupon_w AvgFeat_large_w AvgFeat_medium_w AvgFeat_small_w AvgPriceRed_w/  rantwo ; 
run;

/*As Hausman test rejecting the null so we will run Fixed effect*/
/* running random effect two way model*/
proc panel data=SB_AvgPPU_F_PR_D_edit plots =None;       
id IRI_KEY WEEK;       
model TotalSales_w=AvgPrice_w AvgDisplay_w AvgFeat_coupon_w AvgFeat_large_w AvgFeat_medium_w AvgFeat_small_w AvgPriceRed_w/  fixtwo ; 
run;
/********************************************End of Fixed Effect Code***************************************************************/
/*Location Data*/
Data location;
infile "H:\laundet\Delivery_Stores"  firstobs = 2;
/*LENGTH IRI_KEY  Market_Name$ 22 Open 8;*/
input IRI_KEY OU$ EST_ACV Market_Name $20-44 Open Clsd MskdName$;
run;
proc print data=location(obs=6);run;
/*sorting groc_prod data*/
proc sort data=groc_prod;
by Iri_key;
run;
/*sorting location data*/
proc sort data=location;
by Iri_key;
run;
data groc_prod_location;
merge groc_prod(IN=aa)location;
by IRI_KEY;
if aa;
run;
/*proc print data=groc_prod_location(obs=20);run;*/
/* Checking for missing data in groc_prod_location in sas*/
/* create a format to group missing and nonmissing */
proc format;
 value $missfmt ' '='Missing' other='Not Missing';
 value  missfmt  . ='Missing' other='Not Missing';
run;
 
proc freq data=groc_prod_location; 
format _CHAR_ $missfmt.; /* apply format for the duration of this PROC */
tables _CHAR_ / missing missprint nocum nopercent;
format _NUMERIC_ missfmt.;
tables _NUMERIC_ / missing missprint nocum nopercent;
run;
/* no missing data till now*/
/*Panel_demo Data - I have added the Panel Data WEEK and IRI_KEY Column manually using Vlookup in excel*/
PROC IMPORT DATAFILE="H:\laundet\ads_demo.csv" OUT =panel_demo DBMS=csv replace;
RUN;
proc print data=panel_demo(obs=6);run;
/*Checking missing data in Panel_demo file*/
proc means data=panel_demo NMISS N; run;
data Household_panel;
set panel_demo(Drop = Panelist_Type MALE_SMOKE FEM_SMOKE Language HISP_FLAG HISP_CAT HH_Head_Race__RACE2_ Microwave_Owned_by_HH market_based_upon_zipcode);
run;
proc print data=Household_panel(obs=6);run;
proc means data=Household_panel NMISS N; run;
/*sorting panel data by week*/
proc sort data=Household_panel;
by Week;
run;
/*sorting groc_prod_location data by week*/
proc sort data=groc_prod_location;
by Week;
run;
/*Merging panel data with groc_prod_location data*/
data peanbutr_final;
merge groc_prod_location(IN=aa)Household_panel;
by Week;
if aa;
run;
proc means data=peanbutr_final NMISS N;run;

proc print data=peanbutr_final(obs=10);run;
data groc_prod_loc_1;
set peanbutr_final;
if L2 = 'POWDER LAUNDRY DETERGENT';
run;
data groc_prod_loc_2;
set groc_prod_loc_1;
if Brand in ('ARM & HAMMER FABRICARE','ARM & HAMMER') then brand='ARM&HAMMER';
else if Brand in ('CHEER') then brand='CHEER';
else if Brand in ('GAIN') then brand='GAIN';
else if Brand in ('SURF') then brand='SURF';
else if Brand in ('TIDE') then brand='TIDE';
else brand='Brand';
run;

data groc_prod_loc_3; 
set groc_prod_loc_2;
   length brand_final $29;
   format brand_final $29. ;
   informat brand_final $29.;
run;

data groc_prod_loc_final;
set groc_prod_loc_3;
if brand= 'ARM&HAMMER' then brand_final='ARM&HAMMER';
else if brand= 'CHEER' then brand_final='CHEER';
else if brand= 'GAIN' then brand_final='GAIN';
else if brand= 'SURF' then brand_final='SURF';
else if brand= 'TIDE' then brand_final='TIDE';
else brand_final='OTHER';
run;
/*Dropping Some more irrelevant columns from the data*/
data groc_prod_loc_final;
set groc_prod_loc_final( DROP = L1 L4 Level _STUBSPEC_1542RC);
run;
/*Creating a permanent dataset for the final file*/
Libname cc "C:\Users\sxs180240\Desktop";
data cc.groc_prod_loc_final;
set groc_prod_loc_final;
run;
LIBNAME project "C:\Users\sxs180240\Desktop";
data project.laundry_1;
set 'C:\Users\sxs180240\Desktop\groc_prod_loc_final.sas7bdat';
run;
proc print data=project.laundry_1(obs=10);run;
/* Total UPCs sold by each brand*/
/* And the market share of each brand  */
proc freq data=project.laundry_1 ORDER=FREQ; 
table brand_final;
run;
PROC SQL;
CREATE VIEW project.market_share as
SELECT brand, 
	   total_units_sold, (total_units_sold*100/SUM(total_units_sold)) as percent_units_sold,
	   total_revenue, (total_revenue*100/SUM(total_revenue)) as percent_revenue
FROM (SELECT brand_final as brand, SUM(UNITS) as total_units_sold, SUM(DOLLARS) as total_revenue 
	  FROM project.laundry_1
	  GROUP BY brand_final)
;
QUIT;

proc export data=project.market_share
outfile="C:\Users\sxs180240\Desktop\market_share.csv"
dbms=csv
replace;
run;
proc sql;
create table project.laundry_1_ARM as
SELECT *
FROM project.laundry_1
WHERE brand_final ='ARM&HAMMER';
quit;
/* PS II: RFM and clustering*/
/********************************************begin of RFM Code***************************************************************/

/* RFM and customer Segmentation */
%aaRFM;
%EM_RFM_CONTROL
(
   Mode = T,              
   InData = project.laundry_1_ARM  ,            
   CustomerID = Panelist_ID,        
   N_R_Grp = 5,         
   N_F_Grp = 5,         
   N_M_Grp = 5,         
   BinMethod = I,          
   PurchaseDate = WEEK,      
   PurchaseAmt = DOLLARS,       
   SetMiss = N,                                                         
   SummaryFunc = SUM,
   MostRecentDate = ,
   NPurchase = ,         
   TotPurchaseAmt = ,  
   MonetizationMap = Y, 
   BinChart = Y,        
   BinTable = Y,        
   OutData = project.RFM_RESULTS,           
   Recency_Score = recency_score,     
   Frequency_Score = frequency_score,   
   Monetary_Score = monetary_score,    
   RFM_Score = rfm_score           
);
proc print data=project.rfm_results(obs=10);run;
proc fastclus data=project.rfm_results maxclusters=5 mean=temp out=project.rfm_output_v1;
var recency_score frequency_score monetary_score;
run;
proc print data=project.rfm_output_v1(obs=10);run;
PROC SQL;
CREATE VIEW project.rfm_output AS 
SELECT a.*,b.rfm_score,b.Cluster FROM project.laundry_1 a inner join
project.rfm_output_v1 b 
on b.panelist_id=a.panelist_id;
QUIT;
proc print data=project.rfm_output(obs=10);run;
/*Frequency of different clusters*/
proc freq data=project.rfm_output ORDER=FREQ; 
table Cluster;
run;
data project.cluster1;
set project.rfm_output;
if Cluster=1;
run;
data project.cluster2;
set project.rfm_output;
if Cluster=2;
run;
data project.cluster3;
set project.rfm_output;
if Cluster=3;
run;
data project.cluster4;
set project.rfm_output;
if Cluster=4;
run;
data project.cluster5;
set project.rfm_output;
if Cluster=5;
run;
proc print data=project.cluster1(obs=20); var cluster rfm_score;run;
proc print data=project.cluster2(obs=20); var cluster rfm_score;run;
proc print data=project.cluster3(obs=20); var cluster rfm_score;run;
proc print data=project.cluster4(obs=20); var cluster rfm_score;run;
proc print data=project.cluster5(obs=20); var cluster rfm_score;run;


/*Descriptive statistics on clustered data*/
/*Sales Analysis across Cluster*/
PROC means DATA=project.rfm_output;
VAR dollars;class cluster; RUN;

/* Distribution of Age across cluster*/
proc freq data= project.rfm_output;
table cluster*HH_AGE/ out=CellCountsTrain;
run;

/*Distribution of Occupation across Cluster*/

proc freq data= project.rfm_output;
table cluster*HH_OCC/ out=CellCountsTrain;
run;

/********************************************End of RFM Code***************************************************************/


/* PS III: multilogit*/
/********************************************Begin of multilogit Code***************************************************************/

data laund_groc;
set groc;
VEND_new= put(VEND,z5.);
run;


data laund_groc;
set laund_groc;
ITEM_new=put(ITEM,z5.);
run;

/* creating new column in grocery data for merging purpose*/
data laund_groc;
set laund_groc;
if SY ='88' then upc_new =cats(of SY GE VEND_new ITEM_new);
else upc_new = cats(of  GE VEND_new ITEM_new);
 run;
proc print data=laund_groc(obs=5);run;

data laund_prod;
set laun;
VEND_new=put(input(VEND,best5.),z5.);
run;


data laund_prod;
set laund_prod;
ITEM_new=put(input(ITEM,best5.),z5.);
run;

/* creating new column in product dataset for merging purpose*/
data laund_prod;
set laund_prod;
if SY ='88' then upc_new =cats(of SY GE VEND_new ITEM_new);
else upc_new = cats(of  GE VEND_new ITEM_new);
 run;
proc print data=laund_prod(obs=5);run;

/* sorting grocery data*/
proc sort data=laund_groc;
by upc_new;
run;

/* sorting product  data*/
proc sort data=laund_prod;
by upc_new;
run;

data laund_groc;
set laund_groc;
drop SY GE VEND ITEM;
run;

data laund_prod;
set laund_prod;
drop  SY GE VEND ITEM;
run;

/*merging grocery and prod data*/
data groc_prod_ml;
merge laund_groc( IN=aa) laund_prod;
by upc_new;
if aa;
run;
proc print data=groc_prod_ml(obs=6);run;

data groc_prod_ml_1;
set groc_prod_ml;
if L2 = 'POWDER LAUNDRY DETERGENT';
run;
proc print data= groc_prod_ml_1(obs =6);run;

data groc_prod_ml_2;
set groc_prod_ml_1;
if Brand in ('ARM & HAMMER FABRICARE','ARM & HAMMER') then brand='ARM&HAMMER';
else if Brand in ('CHEER') then brand='CHEER';
else if Brand in ('GAIN') then brand='GAIN';
else if Brand in ('SURF') then brand='SURF';
else if Brand in ('TIDE') then brand='TIDE';
else brand='Brand';
run;

data groc_prod_ml_3; 
set groc_prod_ml_2;
   length brand_final $29;
   format brand_final $29. ;
   informat brand_final $29.;
run;

data groc_prod_ml_4;
set groc_prod_ml_3;
if brand= 'ARM&HAMMER' then brand_final='ARM&HAMMER';
else if brand= 'CHEER' then brand_final='CHEER';
else if brand= 'GAIN' then brand_final='GAIN';
else if brand= 'SURF' then brand_final='SURF';
else if brand= 'TIDE' then brand_final='TIDE';
else brand_final='OTHER';
run;

proc print data= groc_prod_ml_4(obs =6);run;

data groc_prod_ml_final;
set groc_prod_ml_4;
keep IRI_KEY WEEK UNITS DOLLARS F D PR upc_new VOL_EQ brand_final;
run;

proc print data= groc_prod_ml_final(obs =6);run;

data groc_prod_ml_final;
set groc_prod_ml_final;
PPU = ((dollars/units)/vol_eq)/16;
run;
data Household_panel_logit;
set Household_panel;
keep  Panelist_ID Family_Size Combined_Pre_Tax_Income_of_HH HH_AGE ;
run;

data Household_panel_logit;
set Household_panel_logit(rename= (Combined_Pre_Tax_Income_of_HH=HH_Income));
run;
data laundry_panel;
infile 'H:\laundet\laundet_PANEL_GR_1114_1165.dat' 
delimiter ='09'x firstobs=2 missover;
input PANID WEEK UNITS OUTLET $ DOLLARS IRI_KEY COLUPC;
run;
proc print data=laundry_panel(obs=6);run;
data laundry_panel;
set laundry_panel(rename=(PANID=Panelist_ID));
run;
proc print data=laundry_panel_1(obs=6);run;

/*sorting panel data by week*/
proc sort data=Household_panel_logit;
by Panelist_ID;
run;

proc sort data=laundry_panel;
by Panelist_ID;
run;

/*Merging panel data with household panel logit data*/
data panel_merge;
merge laundry_panel(IN=aa)Household_panel_logit;
by Panelist_ID;
if aa;
run;
proc print data=panel_merge(obs=6);run;
data groc_prod_ml_final;
set groc_prod_ml_final;
upc=input(upc_new,best13.);
run;

proc sql;
create table panel_merge as select * from panel_merge;
run;

proc sql;
create table groc_prod_ml_final as select * from groc_prod_ml_final;
run;

proc print data =panel_merge(obs=6);run;

proc print data = groc_prod_ml_final(obs=6);run;

proc sql;
create table merge_final as select a.*,b.* from panel_merge a left join groc_prod_ml_final b
on a.IRI_KEY = b.IRI_KEY
and  a.WEEK = b.WEEK
and  a.COLUPC = b.upc ;
run;

proc contents data = groc_prod ; run;

data merge_final;
set merge_final;
where brand_final ne ' ' ;
run;
proc sql;
select count(*) from merge_final where HH_AGE = . ; run;

proc sql;
select count(*) from merge_final  ; run;

data merge_final;
set merge_final;
where HH_AGE ne . ;
run;

data merge_final;
set merge_final;
if F='NONE' then F_num= 0;
else F_num =1;
run;

Libname cc "C:\Users\sxs180240\Desktop";
data cc.merge_final;
set merge_final;
run;

proc freq data=merge_final; table brand_num;run;
proc means data=merge_final;run;
/*Logit model */

proc logistic data = merge_final;
class brand_final(ref = "OTHER");
model brand_final = HH_Income Family_Size F_num D PR PPU /link=glogit;
run;


















