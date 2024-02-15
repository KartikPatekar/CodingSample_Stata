/************************************************************************

	Title: Computing School Value Index
	Author: Kartik Patekar
	Description: This code computes School Value Index (SVI) as a measure of school quality. The details of the construction can be found in section 3.1 here: https://kartikpatekar.github.io/KP_Writing_Sample.pdf

************************************************************************/


***************
** Local Directories
***************
	
	global input_data = "C:\Users\kartik\Dropbox\WritingSample\CodingSample_Stata\Data\input\"
	global output_data = "C:\Users\kartik\Dropbox\WritingSample\CodingSample_Stata\Data\output\"
	global results = "C:\Users\kartik\Dropbox\WritingSample\CodingSample_Stata\results\"
	global gis_files = "C:\Users\kartik\Dropbox\WritingSample\CodingSample_Stata\Data\gis\"

	
	* Input files
	global RTE_school_list = "$input_data\2022_RTE_Schools_list.dta"
	global dise_scraped = "$input_data\2022_dise_scraped_final.dta"
	global population_census = "$input_data\shrug_population_census.dta"
	global dise_shrid2_matching = "$input_data\dise_shrid2_map.dta"
	global school_fees = "$input_data\Fees_info.dta"
	
	* Output files
	global filtered_village_list = "$output_data\filtered_village_list.dta"
	global sample_schools = "$output_data\sample_schools.dta"
	global dise_schools_with_details = "$output_data\dise_schools_with_details.dta"
	global sample_schools_with_details = "$output_data\sample_schools_with_details.dta"
	global school_list_pred_fees = "$output_data\school_list_pred_fees.dta"
	global village_feepred_data = "$output_data\village_feepred_data.dta"
	
	* Retuls files
	global BalTab_school_facilties = "$results\BalTab_school_facilties.tex"
	global BalTab_school_SVI = "$results\BalTab_school_SVI.tex"
	
	global svi_coeffs = "$results\svi_coeffs.tex"
	global reg_res_excel = "$results\School_index_comparison.xlsx"
***************
** Useful Variables
***************
	// Cut off to classify a habitation as a village. Somewhat arbitrary
	global village_pop_cutoff = 20000 
	

***************
** Get a list of villages that have 1 RTE. This is done by using school list
***************
	
	* load data
	use "$RTE_school_list" , clear
	keep Udise_code ClassName shrid2
	rename Udise_code udiseschcode 

	* Drop schools that are not operational
	merge m:1 udiseschcode using "$dise_scraped", keepusing(isoperational202122) keep(3) nogen
	keep if isoperational202122 == 0
	drop isoperational202122

	rename udiseschcode Udise_code 

	
	* collapse from row indexed by class in school to village level
	gen has_class1 = (ClassName== "1st-Class")
	gen has_preprimary = (ClassName!= "1st-Class")

	collapse (sum) has_class1 has_preprimary, by(shrid2 )
	replace has_class1 = (has_class1 > 0)
	replace has_preprimary = (has_preprimary > 0)
	
	
	* Remove towns and cities using cutoff
	merge 1:1 shrid2 using "$population_census", keepusing(pc11_pca_tot_p) keep(3) nogen
	keep if pc11_pca_tot_p <= $village_pop_cutoff
	drop pc11_pca_tot_p 
	
	* Save filtered village list
	save "$filtered_village_list", replace

	
***************
** Get a list of all schools in these villages (both RTE and public) which will make our sample
***************
	use "$filtered_village_list", clear
	
	merge 1:m shrid2 using "$dise_shrid2_matching", keepusing(udiseschcode) keep(3) nogen
	
	*Set an indicator of whether school is RTE or not

	rename udiseschcode  Udise_code 	
	merge 1:m Udise_code using "$RTE_school_list", keepusing(RTE_Seats_Total)
	
	drop if _merge == 2
	gen is_RTE_sch = (_merge == 3)
	drop _merge

	collapse (sum) RTE_Seats_Total (mean)  is_RTE_sch , by(Udise_code  shrid2)

	
	* Drop schools that are not public but also not RTE
	rename Udise_code udiseschcode 
	merge 1:1 udiseschcode  using "$dise_scraped", keepusing(schmgmtdesc) keep(3) nogen
	rename udiseschcode Udise_code 

	drop if is_RTE_sch  == 0 & (schmgmtdesc == "Private Unaided (Recognized)")
	drop schmgmtdesc
	
	
	* Remove villages from filtered_village_list that do not have any public schools
	
	tempfile temp_file
	save `temp_file', replace
	
	drop if is_RTE_sch  == 1
	keep shrid2
	duplicates drop
	
	merge 1:1 shrid2 using "$filtered_village_list", keep(3) nogen
	save "$filtered_village_list", replace
	
	keep shrid2
	merge 1:m shrid2 using `temp_file', keep(3) nogen
	
	label variable RTE_Seats_Total "Total RTE Seats"
	label variable is_RTE_sch "is this an RTE school?"

	* Save the list of sample schools for further analysis
	save "$sample_schools", replace
	


***************
** Get facilities data and label them for these schools
***************
	use "$sample_schools", clear
	
	rename Udise_code udiseschcode 
	
	merge 1:1 udiseschcode using "$dise_scraped", keepusing(schlocdesc  schtypedesc classfrom classto schmgmtcstatedesc clusterid class112withpreprimary num_teachers ///
		boundarywall noofboystoilets noofgirlstoilets noofcwsntoilets functionalgenerator library readingcorner bookbank functionallaptop functionaldesktop functionaltablet /// 
		functionalscanner functionalprinter functionalwebcam functionaldigiboard internet  has_detailed_data)
	
	gen is_sample_school = (_merge == 3)
	keep if has_detailed_data == 1
	drop _merge has_detailed_data

	
		
	********************
	* Label variables

		gen is_school_urban = (schlocdesc == "Urban") if schlocdesc != ""
		drop schlocdesc
		label variable is_school_urban "Is Urban?"
		

		gen is_school_coed = (schtypedesc == "Co-educational") if schtypedesc != ""
		drop schtypedesc 
		label variable is_school_coed  "Is School Co-Ed?"
		
		label variable schmgmtcstatedesc  "School Mangement"
		label variable clusterid  "Cluster ID"
		label variable num_teachers "Number of Teachers"
		
		rename class112withpreprimary total_enroll_all_class 
		label variable total_enroll_all_class "Total Students in School"
						
		gen has_pucca_boundary_walls = (boundarywall  == "1-Pucca" | boundarywall  == "2-Pucca but broken" ) if boundarywall  != ""
		gen has_broken_pucca_boundary = (boundarywall  == "2-Pucca but broken" ) if boundarywall  != ""
		drop boundarywall  
		label variable has_pucca_boundary_walls  "Has pucca boundary walls"
		label variable has_broken_pucca_boundary "Has pucca but broken boundary walls"
		
		gen has_functionalgenerator = (functionalgenerator > 0) if functionalgenerator !=.
		drop functionalgenerator 
		label variable has_functionalgenerator "Has functional generator"
		
		gen has_library = (library == "1-Yes") if library != ""
		label variable has_library  "Has library"
		
		gen has_readingcorner = (readingcorner == "1-Yes") if library != ""
		label variable has_readingcorner "Has reading corner"
		
		gen has_bookbank = (bookbank == "1-Yes") if library != ""
		label variable has_bookbank "Has book bank"
		
		gen has_internet = (internet == "1-Yes") if library != ""
		label variable has_internet "Has internet access"

		
		drop library readingcorner bookbank internet
		
		gen per_stu_toilets = (noofboystoilets+ noofgirlstoilets+ noofcwsntoilets) / total_enroll_all_class
		label variable per_stu_toilets  "Number of toilets per student" 
		gen has_cwsn_toilets = (noofcwsntoilets > 0) if noofcwsntoilets != .
		label variable has_cwsn_toilets "has CWSN toilet"
		gen has_girls_toilets = (noofgirlstoilets > 0) if noofgirlstoilets != .
		label variable has_girls_toilets "has girls' toilet"
		
		gen teacher_student_ratio = (num_teachers) / total_enroll_all_class
		label variable teacher_student_ratio  "Teacher Student Ratio"
		
		gen per_stu_pc = (functionallaptop + functionaldesktop + functionaltablet) / total_enroll_all_class
		label variable per_stu_pc "Number of Desktops\Laptops per student"
		
		gen has_scaner_printer = (functionalscanner + functionalprinter > 0) 
		label variable has_scaner_printer "has scannet or printer"
		
		gen has_digiboard = (functionaldigiboard > 0) 
		label variable has_digiboard "has digiboard"
		
		gen has_webcam = (functionalwebcam > 0) 
		label variable has_digiboard "has webcam"
		
		
		
		gen per_stu_laptop = (functionallaptop / total_enroll_all_class)
		gen per_stu_desktop = (functionaldesktop / total_enroll_all_class)
		gen per_stu_tablet = (functionaltablet / total_enroll_all_class)
		gen per_stu_scanner = (functionalscanner / total_enroll_all_class)
		gen per_stu_printer = (functionalprinter / total_enroll_all_class)
		gen per_stu_webcam = (functionalwebcam / total_enroll_all_class)
		gen per_stu_digiboard = (functionaldigiboard / total_enroll_all_class)
		
		
		label variable per_stu_laptop "Number of laptops per student"
		label variable per_stu_desktop "Number of desktops per student"
		label variable per_stu_tablet "Number of tablets per student"
		label variable per_stu_scanner "Number of scanner per student"
		label variable per_stu_printer "Number of printer per student"
		label variable per_stu_webcam "Number of webcam per student"
		label variable per_stu_digiboard "Number of digiboard per student"
		
		gen has_desktop_laptop = (functionallaptop + functionaldesktop)
		replace has_desktop_laptop = (has_desktop_laptop > 0) if has_desktop_laptop != .
		label variable has_desktop_laptop "Has desktop or laptop"
		
	
	
	* Save data
		save "$dise_schools_with_details", replace


********************
* make balance table for facilties between RTE and non-RTE schools
********************
		
	keep if is_sample_school == 1
	save "$sample_schools_with_details", replace


	balancetable is_RTE_sch is_school_urban is_school_coed total_enroll_all_class teacher_student_ratio has_pucca_boundary_walls has_broken_pucca_boundary has_functionalgenerator has_library has_readingcorner ///
			has_bookbank has_desktop_laptop has_internet per_stu_laptop per_stu_desktop per_stu_tablet per_stu_scanner per_stu_printer per_stu_webcam per_stu_digiboard ///
			using "$BalTab_school_facilties" , ctitles("non-RTE schools" "RTE_schools" "Difference") modify varlabels sheet("RTE vs non-RTE balance table") replace
		
	
	
********************
* Run Regression to compute SVI
********************
	
	*load school fees and faciltiies data
	use "$school_fees", clear
	drop if Fees == 0 | Fees == 7000
	collapse (mean) Fees, by(Udise_code)

	rename Udise_code udiseschcode 
	merge 1:1 udiseschcode using "$dise_schools_with_details", keep(3) nogen
	
	* Run Regression over Fees
	
	gen log_Fees = log10(Fees)
	egen long fe_shrid = group(shrid2)	
	xtset fe_shrid

	
	* List of predictors
	global pred_vars total_enroll_all_class has_pucca_boundary_walls has_functionalgenerator has_library ///
	has_internet per_stu_toilets has_cwsn_toilets teacher_student_ratio ///
	per_stu_pc has_scaner_printer has_digiboard has_webcam

	est clear	
	
	* Regression with no fixed effects
	reg log_Fees $pred_vars	
	eststo m_nofe, title("no fixed effects")

	* Regression with village fixed effects
	xtreg log_Fees $pred_vars, fe vce(robust)	
	eststo m_vilfe, title("village fixed effects")
	
	* Write to tex file
	esttab m_vilfe m_nofe  using "$svi_coeffs" , title("SVI calculation coefficients" \label{model1a}) ///
		replace style(tex) cells(b(star fmt(3)) se(par fmt(2))) legend label varlabels(_cons constant)  ///
		 stats(N N_g r2_o r2 , fmt(0 0 2 2) labels(Observations "No. of individuals" Overall-R$^2$ R$^2$))	///
		 numbers lines parentheses nolz  nodepvars

	* Save regression results in excel
	mat reg_result = e(b)'
	matlist reg_result
	
	putexcel set $reg_res_excel , sheet("Fees regression", replace ) modify
	putexcel A1 = matrix(reg_result), rownames


********************
* Lets predict fees for our sample schools
********************
	
	use "$dise_schools_with_details", clear
	
	cap drop *SVI*
	
	gen constant = 1

	gen SVI = .
	
	* Matrix operation to calculate
	mata
	st_view(D=., ., "$pred_vars constant")
	B = st_matrix("reg_result")
	st_store(., "SVI", D*B)
	end
	drop constant
		
	drop if SVI == .

	save "$dise_schools_with_details", replace
	
	* CUt off outliers at 99 percentile
	sum SVI, d
	gen SVI_cut = SVI
	replace SVI_cut = r(p99) if SVI_cut > r(p99)

	rename udiseschcode Udise_code
	merge 1:1 Udise_code using "$sample_schools", keepusing() keep(3) nogen
	rename Udise_code udiseschcode 

	
********************
* Comparing RTE and non RTE schools
********************

	balancetable is_RTE_sch SVI ///
		using "$BalTab_school_SVI" , ctitles("non-RTE schools" "RTE_schools" "Difference") modify varlabels sheet("RTE vs non-RTE balance - Fees") replace
	
	qplot  SVI_cut, over(is_RTE_sch) scheme(s1color) c(J J) xla(0 "0" 1 "1" 0.2(0.2)0.8, format ("%02.1f") ang(h)) ytitle("School Value Index") xtitle("quantile") ///
		 legend( label(1 "non-RTE schools") label(2 "RTE schools")) title("RTE vs non-RTC Schools" "Quantile plot for School Value Index") msymbol(i i)

	graph export "$results\1_RTE_YN_SVI_cut_Quantile.png", replace


********************
* Save school pred fees
********************
	keep udiseschcode shrid2 RTE_Seats_Total is_RTE_sch clusterid SVI is_RTE_sch total_enroll_all_class
	save "$school_list_pred_fees", replace

********************
* Lets do Village level comparision
********************

	use "$school_list_pred_fees", replace

	* Compute village level max and mean SVI (separately for RTE and non-RTE schools) by weighting schools with enrollment
	gen one = 1
	gen SVI_enroll = SVI * total_enroll_all_class 
	
	collapse (sum) total_enroll_all_class RTE_Seats_Total  SVI_enroll  num_schools = one (max) best_SVI = SVI , by(shrid2 is_RTE_sch)
	gen mean_SVI = SVI_enroll   / total_enroll_all_class
	
	gen is_RTE_str = "_RTE" if is_RTE_sch == 1
	replace is_RTE_str = "_nonRTE" if is_RTE_sch == 0
	
	drop  is_RTE_sch
	
	reshape wide total_enroll_all_class best_SVI mean_SVI num_schools RTE_Seats_Total SVI_enroll, i(shrid2) j(is_RTE_str) string
	
	* Clean data 
	drop RTE_Seats_Total_nonRTE
	rename  RTE_Seats_Total_RTE RTE_Seats_Total
	
	keep if best_SVI_RTE != .
	keep if best_SVI_nonRTE != .
	
	* Compute dSVI
	gen dSVI_max = best_SVI_RTE - best_SVI_nonRTE 
	gen dSVI_mean = mean_SVI_RTE - mean_SVI_nonRTE 

		
	* Make some comparision plots
	hist dSVI_max, freq  title("Village level Histogram" "Comparing avg RTE and non-RTE school" ) xtitle("Difference between best SVI of private and public schools")
	graph export "$results\2_vill_best_RTE_noRTE.png", replace 

	hist dSVI_mean, freq  title("Village level Histogram" "Comparing avg RTE and non-RTE school" ) xtitle("Difference between avg SVI of private and public schools")
	graph export "$results\2_vill_avg_RTE_noRTE.png", replace 

	save "$village_feepred_data", replace



********************
* Plot village level dSVI_max
********************

	use "$village_feepred_data", replace
	
	merge 1:1 shrid2 using "$gis_files\filt_village_db.dta", keep(3) nogen keepusing(_ID)
	
	grmap dSVI_max using "$gis_files\filt_village_cd.dta", id(_ID) fcolor(BuYlRd) ocolor(white white white white white) clnumber(5) /// 
		polygon(data("$gis_files\cg_map.dta") osize(vthin)) legend(bplace(seast)) title("CG villages differential SVI between ""best private and public school")
		
	graph export "$results\dSVI_map.png", replace 
		

