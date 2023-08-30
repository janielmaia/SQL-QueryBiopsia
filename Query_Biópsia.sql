/*XPID - Descrição:	A pedido do time de Pesquisa clínica realizar a inclusão dos itens abaixo na Query descrita: 
•	Data de Nascimento
•	Sexo
•	Local de realização do exame
1 - Busca CIPs e FAPs de pacientes que tenham biópsias ou anatomopatológico contendo os termos esofago, gastro, estomago 
2 - Seleciona os exames de anatomia patológica e imunohistoquímica */


with biopsy as (
  SELECT 
    motion.patient_motion_id,
    motion.cip,
    motion.fap,
    EXTRACT(DATE FROM motion.test_collection_date) as date_exam,
    motion.test_alphacode,
    motion.test_dasacode,
    motion.test_result,
    motion.unit_measurement_initials,
    lower(REGEXP_REPLACE(NORMALIZE(motion.test_text_result, NFD), r'\pM', ''))as test_text_result,
    lower(REGEXP_REPLACE(NORMALIZE(motion.nomecorrente, NFD), r'\pM', '')) as nomecorrente,
    motion.abreviaturacorrente
  FROM `interoper-dataplatform-prd.idd_bi_container_data_mart.idd_bi_dm_motion_exam_ac` as motion
  WHERE motion.release_date >= '2020-01-01' 
  AND motion.test_dasacode in ('38342', '38349', '30165', '1318 ','38343') 
  AND ( REGEXP_CONTAINS(lower(motion.test_text_result), r'es(o|ô)fag') OR REGEXP_CONTAINS(lower(motion.nomecorrente), r'es(o|ô)fag')
        OR REGEXP_CONTAINS(lower(motion.test_text_result), r'g(a|á)stric') OR REGEXP_CONTAINS(lower(motion.nomecorrente), r'g(a|á)stric')
        OR REGEXP_CONTAINS(lower(motion.test_text_result), r'est(o|ô)mag') OR REGEXP_CONTAINS(lower(motion.nomecorrente), r'est(o|ô)mag') )

),

/* 3 - Extrai as flags dos textos de biopsias */
feature_extraction_biopsy as (
SELECT 
  biopsy.*,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'adenocarc') = TRUE THEN 1 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'cancer') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'neoplas') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'tumor') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'malign') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(nao ha)|(ausencia de)[.]{0,15}malignidade') = TRUE THEN 0
    ELSE 0  END as flag_cancer,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'adenocarc') = TRUE THEN 1 
    ELSE 0 END as flag_adenocarcinoma,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(cirurg|ctomia)') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'(cirurg|ctomia)') = TRUE THEN 1 
    ELSE 0 END as flag_cirurgia,
  CASE
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'endoscop') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'endoscop') = TRUE THEN 1 
    ELSE 0 END as flag_endoscopia,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(gastric)|(estomag)') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'(gastric)|(estomag)') = TRUE THEN 1 
    ELSE 0 END as loc_estomago,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'esofag') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'esofag') = TRUE THEN 1 
    ELSE 0 END as loc_esofago,
  CASE
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(transi|jun)(ç|c)ao') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'(transi|jun)(ç|c)ao') = TRUE THEN 1
    ELSE 0 END as loc_transicao_juncao,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(esofago[.]{0,3}gastric)|(gastro[.]{0,3}esofag)') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'(esofago[.]{0,3}gastric)|(gastro[.]{0,3}esofag)') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'teg') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(nomecorrente), r'teg') = TRUE THEN 1  
    ELSE 0 END as loc_esofagogastrica
FROM biopsy),


/* 4 - Busca os exames de endoscopia */
endoscopy as (
  SELECT DISTINCT 
    origin_patient_system_id as patient_motion_id,
    accession_number, 
    DATE(patient_visit_date) as patient_visit_date, 
    CASE WHEN 
      medical_report_carestream IS NULL THEN medical_report_sislu
      ELSE medical_report_carestream END as test_text_result
  FROM `interoper-dataplatform-prd.idd_bi_container_data_mart.idd_bi_dm_motion_exam_sisl_rdi` 
  WHERE motion_exam_code in ('12651', '28797', '12210','2872','12263','23940')
),


/* 5 - Extrai as flags dos textos de endoscopia */
feature_extraction_endoscopy as (
  SELECT 
    endoscopy.*,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'adenocarc') = TRUE THEN 1 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'cancer') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'neoplas') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'tumor') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'malign') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(nao ha)|(ausencia de)[.]{0,15}malignidade') = TRUE THEN 0
    ELSE 0  END as flag_cancer,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'adenocarc') = TRUE THEN 1 
    ELSE 0 END as flag_adenocarcinoma,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(cirurg|ctomia)') = TRUE THEN 1 
    ELSE 0 END as flag_cirurgia,
  CASE
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'endoscop') = TRUE THEN 1
    ELSE 0 END as flag_endoscopia,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(gastric)|(estomag)') = TRUE THEN 1
    ELSE 0 END as loc_estomago,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'esofag') = TRUE THEN 1
    ELSE 0 END as loc_esofago,
  CASE
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(transi|jun)(ç|c)ao') = TRUE THEN 1
    ELSE 0 END as loc_transicao_juncao,
  CASE 
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'(esofago[.]{0,3}gastric)|(gastro[.]{0,3}esofag)') = TRUE THEN 1
    WHEN REGEXP_CONTAINS(lower(test_text_result), r'teg') = TRUE THEN 1
    ELSE 0 END as loc_esofagogastrica
  FROM endoscopy

),

/* 6 - Empilha os exames */

consolidated_exams as (
SELECT 
  patient_motion_id,
  date_exam,
  test_alphacode as exam,
  test_text_result,
  flag_cancer,
  flag_adenocarcinoma,
  flag_cirurgia,
  flag_endoscopia,
  loc_estomago,
  loc_esofago,
  loc_transicao_juncao,
  loc_esofagogastrica,
FROM feature_extraction_biopsy
WHERE test_alphacode in ('DIAGN', 'INFORME', 'DIAGAPIM')

UNION ALL

SELECT 
  patient_motion_id,
  patient_visit_date as date_exam,
  "ENDOSCOPIA" as exam,
  test_text_result,
  flag_cancer,
  flag_adenocarcinoma,
  flag_cirurgia,
  flag_endoscopia,
  loc_estomago,
  loc_esofago,
  loc_transicao_juncao,
  loc_esofagogastrica,
FROM feature_extraction_endoscopy
WHERE patient_motion_id is not null
),

summarized_patients as (
  SELECT 
    patient_motion_id,
    --ARRAY_AGG(STRUCT(date_exam, exam, test_text_result)) as AP,
    MAX(flag_cancer) as flag_cancer,
    MAX(flag_adenocarcinoma) as flag_adenocarcinoma,
    MAX(flag_cirurgia) as flag_cirurgia,
    MAX(flag_endoscopia) as flag_endoscopia,
    MAX(loc_estomago) as loc_estomago,
    MAX(loc_esofago) as loc_esofago,
    MAX(loc_transicao_juncao) as loc_transicao_juncao,
    MAX(loc_esofagogastrica) as loc_esofagogastrica
  FROM consolidated_exams
  GROUP BY patient_motion_id
),

diagapim as (
  SELECT 
  patient_motion_id,
  date_exam,
  test_text_result 
  FROM feature_extraction_biopsy
  WHERE test_alphacode = 'DIAGAPIM'
)


SELECT 
table_biopsy.patient_motion_id as patient_motion_id,
table_biopsy.date_exam as ap_date_exam,
table_biopsy.test_text_result as ap_laudo,
table_endoscopy.patient_visit_date as endo_laudo,
table_endoscopy.test_text_result as endo_date,
diagapim.date_exam as ihq_date,
diagapim.test_text_result as ihq_laudo,
summarized_patients.flag_cancer,
summarized_patients.flag_adenocarcinoma,
summarized_patients.flag_cirurgia,
summarized_patients.flag_endoscopia,
summarized_patients.loc_estomago,
summarized_patients.loc_esofago,
summarized_patients.loc_transicao_juncao,
summarized_patients.loc_esofagogastrica
from feature_extraction_biopsy as table_biopsy
left join feature_extraction_endoscopy as table_endoscopy
on table_biopsy.patient_motion_id = table_endoscopy.patient_motion_id
and DATE(table_endoscopy.patient_visit_date) BETWEEN DATE_SUB(DATE(table_biopsy.date_exam), INTERVAL 2 DAY) AND DATE_ADD(DATE(table_biopsy.date_exam), INTERVAL 1 DAY)
left join summarized_patients on summarized_patients.patient_motion_id = table_biopsy.patient_motion_id
left join diagapim on diagapim.patient_motion_id = table_biopsy.patient_motion_id
and DATE(diagapim.date_exam) BETWEEN DATE(table_biopsy.date_exam) AND DATE_ADD(DATE(table_biopsy.date_exam), INTERVAL 60 DAY)
where table_biopsy.test_alphacode in ('DIAGN')