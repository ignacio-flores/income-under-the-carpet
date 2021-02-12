# income-under-the-carpet

Here you will find all the necessary STATA code and data to reproduce results from 
"THE CAPITAL SHARE AND INCOME INEQUALITY: INCREASING GAPS BETWEEN MICRO AND MACRO-DATA"
by Ignacio Flores, published in the Journal of Economic Inequality

****************************************************************************************
Download the whole project and run the "run_everything.do" file, which will run -you 
guessed it- everything. But, before doing it, first think about replacing the global 
in line 14 'mydirectory' to wherever you put the folder. Pretty simple, right? Also,
it will produce the file 'tables/data-behind-figures.xlsx' which has tables with
the data used to build figures in the paper. 

In what follows, some details about specific aspects of the project.

(*) The whole thing should take 20-40mins to run. It could certainly be written in a 
more efficient way, but it works, which is the most important. It was one of my first 
projects to write as a PhD student, so please be forgiving when judging. 
(**) The 02a do-file requires the genstack command in stata to be installed. If you 
havent done it, please type the STATA command: ssc install genstack 
****************************************************************************************

*ABOUT NATIONAL ACCOUNTS FROM UN-DATA
You can find the most up-to-date data in the following link: 
http://data.un.org/Explorer.aspx I scrapped it with some R code, which I will not share
because I am not the author. However, you can find all the tables that I used in the 
project (and more) in the "Data/UN/" folder. Accronyms in the names of files refer to
the different institutional sectors: G -> Government; HH -> Households; 
NPISH -> Non-Profits Serving Households; SF-> Financial Corps; 
SnF -> Non-Financial Corps. 

*ABOUT LIS DATA 
All survey data that I use in this study comes from the Luxembourg Income Studies (LIS) 
database, for which direct access to microdata is forbidden due to confidentiality 
agreements between LIS and national statistical offices. To work with it, you have to 
send them code via an interface. The STATA version is limited to retrieve information
only from the log. The rationale is thus to orginse the information in the log as 
something that makes sense as a .csv file, to then be able to copypaste it and use 
the data ('ccyy.csv' and 'ccyy2' in the Data/ folder). The do-file I used to retrieve 
the main survey data is '0a_Lissy2019.do', while '0b_Lissy_currencies.do' was used to 
get information on currencies. These do files are part of the project, but do not run 
with the run_everything.do. 


