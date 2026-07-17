
    DATA: lo_message_container        TYPE REF TO /iwbep/if_message_container,
          /iwbep/if_message_container.

    DATA : ls_payload_data     TYPE zcl_zwm_temp_adv_mpc=>ts_vendor.
    DATA : ls_ZTWM_TEMP_VENDOR TYPE ztwm_temp_vendor.

    DATA : lv_pernr        TYPE ess_emp-employeenumber,
           lv_message_text TYPE bapi_msg.


    DATA : lv_status TYPE c LENGTH 2,
           lv_error  TYPE abap_bool VALUE abap_false.

    TRY.
        io_data_provider->read_entry_data( IMPORTING es_data = ls_payload_data ).

      CATCH: /iwbep/cx_mgw_tech_exception INTO DATA(lcx_mgw_tech_exception).

    ENDTRY.

    CALL METHOD me->/iwbep/if_mgw_conv_srv_runtime~get_message_container
      RECEIVING
        ro_message_container = lo_message_container.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.

    ENDIF.
    GET TIME STAMP FIELD DATA(lv_local_timestamp).

    SELECT SINGLE
      FROM ztwm_temp_vendor
      FIELDS MAX( reqno )
*      WHERE reqno = @ls_payload_data-reqno
      INTO @DATA(lv_req).
    IF lv_req IS INITIAL.
      lv_req = '1000000001'.
    ELSE.
      lv_req = lv_req + 1.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTWM_TEMP_VENDOR'
      EXCEPTIONS
        OTHERS  = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE
      FROM zthr_emp_master
      FIELDS
      area
      WHERE pernr = @lv_pernr
      INTO @DATA(lv_pa).

    "----------------- UNSENT -----------------

    ls_ZTWM_TEMP_VENDOR-reqno        = lv_req.
    ls_ZTWM_TEMP_VENDOR-location     = lv_pa.
    ls_ZTWM_TEMP_VENDOR-vendorname   = ls_payload_data-vendorname.
    ls_ZTWM_TEMP_VENDOR-pincode      = ls_payload_data-pincode.
    ls_ZTWM_TEMP_VENDOR-state        = ls_payload_data-state.
    ls_ZTWM_TEMP_VENDOR-gstin        = ls_payload_data-gstin.
    ls_ZTWM_TEMP_VENDOR-address      = ls_payload_data-address.
    ls_ZTWM_TEMP_VENDOR-updated_by   = lv_pernr.
    ls_ZTWM_TEMP_VENDOR-updated_on   = lv_local_timestamp.

    MODIFY ztwm_temp_vendor FROM ls_ZTWM_TEMP_VENDOR.
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.


    "----------------------Commit or rollback----------------------------------
    IF lv_error = abap_true.
      ROLLBACK WORK.
*      RETURN.
    ELSE.
      COMMIT WORK AND WAIT.
    ENDIF.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTWM_TEMP_VENDOR'.


    IF lv_error = abap_false.

      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>success
          iv_msg_text               = | Vendor created successfully.|
          iv_add_to_response_header = abap_true.
    ELSE.
      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>error
          iv_msg_text               = 'Error while submission.'
          iv_add_to_response_header = abap_true.

    ENDIF.

*    me->copy_data_to_ref(
*     EXPORTING
*       is_data = ls_payload_data
*     CHANGING
*       cr_data = er_entity ).



---------------------------------------------------------------------------------------------------------------------------------------------------

  DATA: lv_today      TYPE sy-datum VALUE sy-datum,
        ls_entity     TYPE zcl_zhr_minimaster_mpc=>ts_employeeminimaster,
        lt_pa0001     TYPE TABLE OF pa0001,
        ls_pa0001     TYPE pa0001,
        lt_pa0034     TYPE TABLE OF pa0034,
        lt_pa0041     TYPE TABLE OF pa0041,
        lv_pernr      TYPE pernr_d.

  lv_today = sy-datum.

  "--------------------------------------------------------------------
  " STEP 1: Read all active PA0001 records
  "--------------------------------------------------------------------
  SELECT * FROM pa0001
    INTO TABLE lt_pa0001
    WHERE begda <= lv_today
      AND endda >= lv_today.

  LOOP AT lt_pa0001 INTO ls_pa0001.
    CLEAR ls_entity.
    lv_pernr = ls_pa0001-pernr.

    "-- PA0001 direct fields --
    ls_entity-personnel_number     = ls_pa0001-pernr.
    ls_entity-personnel_area_code  = ls_pa0001-werks.
    ls_entity-personnel_subarea_code = ls_pa0001-btrtl.
    ls_entity-employee_group_code  = ls_pa0001-persg.
    ls_entity-employee_subgroup_code = ls_pa0001-persk.
    ls_entity-department_code      = ls_pa0001-orgeh.
    ls_entity-position_id          = ls_pa0001-plans.
    ls_entity-cost_center_code     = ls_pa0001-kostl.
    ls_entity-prev_personnel_number = ls_pa0001-pnalt.
    ls_entity-employee_full_name   = ls_pa0001-ename.
    ls_entity-last_changed_date    = ls_pa0001-aedtm.
    ls_entity-last_changed_by      = ls_pa0001-uname.

    "--------------------------------------------------------------------
    " STEP 2: PA0000 — Employment Status
    "--------------------------------------------------------------------
    SELECT SINGLE stat2 FROM pa0000
      INTO ls_entity-employment_status
      WHERE pernr  = lv_pernr
        AND begda <= lv_today
        AND endda >= lv_today.

    "-- T529U: Employment Status Text --
    SELECT SINGLE text1 FROM t529u
      INTO ls_entity-employment_status_txt
      WHERE stat2 = ls_entity-employment_status
        AND sprsl = sy-langu
        AND statn = '2'.

    "--------------------------------------------------------------------
    " STEP 3: PA0002 — Personal Data
    "--------------------------------------------------------------------
    SELECT SINGLE anrex gbdat gesch zzename
      FROM pa0002
      INTO (ls_entity-employee_title,
            ls_entity-date_of_birth,
            ls_entity-gender_code,
            ls_entity-employee_name_hindi)
      WHERE pernr  = lv_pernr
        AND begda <= lv_today
        AND endda >= lv_today.

    "--------------------------------------------------------------------
    " STEP 4: Text Lookups — Area, SubArea, Group, SubGroup, Dept, Position
    "--------------------------------------------------------------------
    SELECT SINGLE name1 FROM t500p INTO ls_entity-personnel_area_text
      WHERE werks = ls_entity-personnel_area_code.

    SELECT SINGLE btext FROM t001p INTO ls_entity-personnel_subarea_text
      WHERE werks = ls_entity-personnel_area_code
        AND btrtl = ls_entity-personnel_subarea_code.

    SELECT SINGLE ptext FROM t501t INTO ls_entity-employee_group_text
      WHERE persg = ls_entity-employee_group_code
        AND sprsl = sy-langu.

    SELECT SINGLE ptext FROM t503t INTO ls_entity-employee_subgroup_text
      WHERE persk = ls_entity-employee_subgroup_code
        AND sprsl = sy-langu.

    SELECT SINGLE orgtx FROM t527x INTO ls_entity-department_text
      WHERE orgeh = ls_entity-department_code
        AND sprsl = sy-langu.

    SELECT SINGLE stext FROM p1000 INTO ls_entity-position_text
      WHERE otype = 'S'
        AND objid = ls_entity-position_id
        AND begda <= lv_today
        AND endda >= lv_today.

    "--------------------------------------------------------------------
    " STEP 5: PA0007 — Work Schedule
    "--------------------------------------------------------------------
    SELECT SINGLE schkz FROM pa0007 INTO ls_entity-work_schedule_rule
      WHERE pernr  = lv_pernr
        AND begda <= lv_today
        AND endda >= lv_today.

    SELECT SINGLE rtext FROM t508a INTO ls_entity-work_schedule_rule_txt
      WHERE schkz = ls_entity-work_schedule_rule
        AND sprsl = sy-langu.

    "--------------------------------------------------------------------
    " STEP 6: PA0041 — Date of Joining & Date of Retirement
    "--------------------------------------------------------------------
    SELECT * FROM pa0041 INTO TABLE lt_pa0041
      WHERE pernr = lv_pernr.
    LOOP AT lt_pa0041 ASSIGNING FIELD-SYMBOL(<lfs_pa0041>).
      CASE <lfs_pa0041>-datar.
        WHEN '01'. ls_entity-date_of_joining     = <lfs_pa0041>-dardt.
        WHEN 'N0'. ls_entity-date_of_retirement  = <lfs_pa0041>-dardt.
      ENDCASE.
    ENDLOOP.

    "--------------------------------------------------------------------
    " STEP 7: PA0105 — User ID / Mobile / Email
    "--------------------------------------------------------------------
    SELECT SINGLE usrid FROM pa0105 INTO ls_entity-system_user_id
      WHERE pernr = lv_pernr AND subty = '0001'
        AND begda <= lv_today AND endda >= lv_today.

    SELECT SINGLE usrid_long FROM pa0105 INTO ls_entity-mobile_number
      WHERE pernr = lv_pernr AND subty = '0011'
        AND begda <= lv_today AND endda >= lv_today.

    SELECT SINGLE usrid_long FROM pa0105 INTO ls_entity-email_address
      WHERE pernr = lv_pernr AND subty = '0010'
        AND begda <= lv_today AND endda >= lv_today.

    "--------------------------------------------------------------------
    " STEP 8: PA0034 — Functional Designations (up to 4)
    "--------------------------------------------------------------------
    SELECT funkt FROM pa0034 INTO TABLE lt_pa0034
      WHERE pernr  = lv_pernr
        AND begda <= lv_today
        AND endda >= lv_today.
    DATA(lv_idx) = 1.
    LOOP AT lt_pa0034 ASSIGNING FIELD-SYMBOL(<lfs_pa0034>).
      DATA(lv_ftext) = ''. " reset
      SELECT SINGLE stext FROM t591a INTO lv_ftext
        WHERE infty = '0034' AND subty = <lfs_pa0034>-funkt AND sprsl = sy-langu.
      CASE lv_idx.
        WHEN 1.
          ls_entity-func_designation_1   = <lfs_pa0034>-funkt.
          ls_entity-func_designation_txt1 = lv_ftext.
        WHEN 2.
          ls_entity-func_designation_2   = <lfs_pa0034>-funkt.
          ls_entity-func_designation_txt2 = lv_ftext.
        WHEN 3.
          ls_entity-func_designation_3   = <lfs_pa0034>-funkt.
          ls_entity-func_designation_txt3 = lv_ftext.
        WHEN 4.
          ls_entity-func_designation_4   = <lfs_pa0034>-funkt.
          ls_entity-func_designation_txt4 = lv_ftext.
      ENDCASE.
      ADD 1 TO lv_idx.
    ENDLOOP.

    "--------------------------------------------------------------------
    " STEP 9: Custom Attributes — ZHRT_ATTR_MASTER
    " (Cadre, Executive, Gazetted, EmpType, Union)
    "--------------------------------------------------------------------
    DATA: lv_attr_type TYPE zhrt_attr_master-zzattr_type,
          lv_attr_val  TYPE zhrt_attr_master-zzattr,
          lv_attr_desc TYPE zhrt_attr_master-zzattr_desc.

    " Cadre (ZZATTR1)
    ls_entity-cadre_code = ls_pa0001-zzattr1.
    SELECT SINGLE zzattr_desc FROM zhrt_attr_master INTO ls_entity-cadre_description
      WHERE zzattr_type = 'CADRE' AND zzattr = ls_pa0001-zzattr1.

    " Executive Category (ZZATTR2)
    ls_entity-executive_category = ls_pa0001-zzattr2.
    SELECT SINGLE zzattr_desc FROM zhrt_attr_master INTO ls_entity-executive_category_text
      WHERE zzattr_type = 'EXEC' AND zzattr = ls_pa0001-zzattr2.

    " Gazetted (ZZATTR3)
    ls_entity-gazetted_category = ls_pa0001-zzattr3.
    SELECT SINGLE zzattr_desc FROM zhrt_attr_master INTO ls_entity-gazetted_category_text
      WHERE zzattr_type = 'GAZET' AND zzattr = ls_pa0001-zzattr3.

    " Employee Type (ZZATTR4)
    ls_entity-employee_type_code = ls_pa0001-zzattr4.
    SELECT SINGLE zzattr_desc FROM zhrt_attr_master INTO ls_entity-employee_type_text
      WHERE zzattr_type = 'EMPTYPE' AND zzattr = ls_pa0001-zzattr4.

    " Union Membership (ZZATTR5)
    ls_entity-union_membership_code = ls_pa0001-zzattr5.
    SELECT SINGLE zzattr_desc FROM zhrt_attr_master INTO ls_entity-union_membership_text
      WHERE zzattr_type = 'UNION' AND zzattr = ls_pa0001-zzattr5.

    "--------------------------------------------------------------------
    " STEP 10: Reporting Hierarchy via FM HRIQ_STRUC_GET
    "--------------------------------------------------------------------
    DATA: lt_struc   TYPE TABLE OF result_struc,
          ls_struc   TYPE result_struc,
          lv_rep_idx TYPE i VALUE 0.

    CALL FUNCTION 'HRIQ_STRUC_GET'
      EXPORTING
        act_otype    = 'S'
        act_objid    = ls_entity-position_id
        act_wegid    = 'ZA002'
        act_plvar    = '01'
        act_begda    = lv_today
        act_endda    = lv_today
      TABLES
        result_struc = lt_struc.

    " Filter OTYPE = 'US', skip first entry (employee itself), rest are supervisors
    DELETE lt_struc WHERE otype <> 'US'.
    SORT lt_struc BY pup ASCENDING.
    DELETE lt_struc INDEX 1.  " Remove employee's own entry

    LOOP AT lt_struc INTO ls_struc.
      ADD 1 TO lv_rep_idx.
      CASE lv_rep_idx.
        WHEN 1.  ls_entity-reporting_officer_id1  = ls_struc-objid.
        WHEN 2.  ls_entity-reporting_officer_id2  = ls_struc-objid.
        WHEN 3.  ls_entity-reporting_officer_id3  = ls_struc-objid.
        WHEN 4.  ls_entity-reporting_officer_id4  = ls_struc-objid.
        WHEN 5.  ls_entity-reporting_officer_id5  = ls_struc-objid.
        WHEN 6.  ls_entity-reporting_officer_id6  = ls_struc-objid.
        WHEN 7.  ls_entity-reporting_officer_id7  = ls_struc-objid.
        WHEN 8.  ls_entity-reporting_officer_id8  = ls_struc-objid.
        WHEN 9.  ls_entity-reporting_officer_id9  = ls_struc-objid.
        WHEN 10. ls_entity-reporting_officer_id10 = ls_struc-objid.
      ENDCASE.
    ENDLOOP.

    "--------------------------------------------------------------------
    " STEP 11: OM Attribute — ZTHR_ORGM_01
    "--------------------------------------------------------------------
    SELECT SINGLE om_attribute FROM zthr_orgm_01
      INTO ls_entity-om_attribute_code
      WHERE persa = ls_entity-personnel_area_code
        AND ( btrtl = ls_entity-personnel_subarea_code OR btrtl = '**' ).

    "--------------------------------------------------------------------
    " STEP 12: Append to result set
    "--------------------------------------------------------------------
    APPEND ls_entity TO et_entityset.

  ENDLOOP.  " End loop PA0001

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------




  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.

    DATA: lo_message_container TYPE REF TO /iwbep/if_message_container,

          lv_error_msg         TYPE bapi_msg.
 
    DATA: BEGIN OF ls_payload_data.

            INCLUDE TYPE zcl_z_lead_n_opporunit_mpc=>ts_leaddetails.

    DATA:   NavLeadToInstruction TYPE STANDARD TABLE OF zcl_z_lead_n_opporunit_mpc=>ts_instruction.

    DATA: END OF ls_payload_data.
 
    DATA : ls_Customer_data TYPE ztlo_m_customer,

           ls_main_data     TYPE ztlo_main,

           ls_Workflow_data TYPE ztlo_workflow.
 
    DATA:  lt_intruction   TYPE STANDARD TABLE OF zcl_z_lead_n_opporunit_mpc=>ts_instruction.

    DATA : lv_pernr        TYPE ess_emp-employeenumber,

           lv_message_text TYPE bapi_msg.
 
    DATA : lv_seq       TYPE seqnr_no.

    DATA : lv_status    TYPE c LENGTH 2.
 
    DATA: lt_Instruct TYPE STANDARD TABLE OF ztlo_cust_inst,

          ls_Instruct TYPE ztlo_cust_inst.
 
    TRY.

        io_data_provider->read_entry_data(

          IMPORTING

            es_data = ls_payload_data ).
 
      CATCH: /iwbep/cx_mgw_tech_exception INTO DATA(lcx_mgw_tech_exception).

    ENDTRY.
 
    lt_intruction = CORRESPONDING #( ls_payload_data-navleadtoinstruction ).
 
    CALL METHOD me->/iwbep/if_mgw_conv_srv_runtime~get_message_container

      RECEIVING

        ro_message_container = lo_message_container.
 
    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'

      EXPORTING

        username                  = sy-uname

      IMPORTING

        employeenumber            = lv_pernr

      EXCEPTIONS

        user_not_found            = 1

        countrygrouping_not_found = 2

        infty_not_found           = 3

        OTHERS                    = 4.

    IF sy-subrc <> 0.

* Implement suitable error handling here

    ENDIF.

    GET TIME STAMP FIELD DATA(lv_local_timestamp).
 
    IF ls_payload_data-zzreqno IS INITIAL.
 
      SELECT SINGLE FROM ztlo_main

         FIELDS MAX( zzreqno )

         INTO @DATA(lv_Req).
 
      IF lv_Req IS NOT INITIAL.

        IF lv_Req(6) = sy-datum(6).

          lv_Req += 1.

        ELSE.

          lv_Req = |{ sy-datum(6) }000001|.

        ENDIF.

        CONDENSE lv_req.

      ELSE.

        lv_Req = |{ sy-datum(6) }000001|.

      ENDIF.

      lv_seq = '1'.

    ELSE.
 
      SELECT SINGLE FROM ztlo_workflow

         FIELDS MAX( zzseqno )

         WHERE zzreqno = @ls_payload_data-zzreqno

         INTO @lv_seq.
 
      lv_Req = ls_payload_data-zzreqno.

      lv_seq += 1.

    ENDIF.
 
    IF ls_payload_data-zzcust_id IS INITIAL.
 
      SELECT SINGLE FROM ztlo_m_customer

        FIELDS MAX( zzcust_id )

        INTO @DATA(lv_custId).
 
      IF lv_custId IS NOT INITIAL.

*        lv_custId += '1'.

*        lv_custId = CONV NUM( lv_custId ) + 1.

        " Remove the leading 'c' and convert the numeric part to an integer

        lv_custId = lv_custId+1(*). " Starting from index 1 to convert the numeric part

        lv_custId += 1.

        lv_custId = |C{ lv_custId }|.

      ELSE.

        lv_custId = |C{ sy-datum+2(2) }0000001|.

      ENDIF.

    ELSE.

      lv_custId = ls_payload_data-zzcust_id.

    ENDIF.
 
    IF ls_payload_data-action = 'D'.

      lv_status = '10'.

    ELSE.

      lv_status = '15'.

    ENDIF.
 
    "Modify table ZTLO_M_CUSTOMER.
 
    CALL FUNCTION 'ENQUEUE_E_TABLE'

      EXPORTING

        mode_rstable   = 'E'

        tabname        = 'ztlo_m_customer'

      EXCEPTIONS

        foreign_lock   = 1

        system_failure = 2

        OTHERS         = 3.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    ls_customer_data-zzcust_id        = lv_custId.

    ls_customer_data-zzlead_name      = ls_payload_data-zzlead_name.

    ls_customer_data-zzl_contact_no   = ls_payload_data-zzl_contact_no.

    ls_customer_data-zzalt_conc_no    = ls_payload_data-zzalt_conc_no.

    ls_customer_data-zz_lead_email    = ls_payload_data-zz_lead_email.

    ls_customer_data-zzcompy_name     = ls_payload_data-zzcompy_name.

    ls_customer_data-zzaddr           = ls_payload_data-zzaddr.

    ls_customer_data-zzlandmark       = ls_payload_data-zzlandmark.

    ls_customer_data-zzpincode        = ls_payload_data-zzpincode.

    ls_customer_data-zzcity           = ls_payload_data-zzcity.

    ls_customer_data-zzdistrict       = ls_payload_data-zzdistrict.

    ls_customer_data-zzstate          = ls_payload_data-zzstate.

    ls_customer_data-zzcountry        = ls_payload_data-zzcountry.

    ls_customer_data-zzcompy_phone    = ls_payload_data-zzcompy_phone.

    ls_customer_data-zzcompy_email    = ls_payload_data-zzcompy_email.

    ls_customer_data-zzpan            = ls_payload_data-zzpan.

    ls_customer_data-zzgstin          = ls_payload_data-zzgstin.

    ls_customer_data-zzchanged_by     = lv_pernr.

    ls_customer_data-zzchanged_on     = lv_local_timestamp.
 
    MODIFY ztlo_m_customer FROM ls_customer_data.
 
 
    COMMIT WORK AND WAIT.
 
    CALL FUNCTION 'DEQUEUE_E_TABLE'

      EXPORTING

        mode_rstable = 'E'

        tabname      = 'ztlo_m_customer'.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    "Modify table ZTLO_MAIN.
 
    CALL FUNCTION 'ENQUEUE_E_TABLE'

      EXPORTING

        mode_rstable   = 'E'

        tabname        = 'ZTLO_MAIN'

      EXCEPTIONS

        foreign_lock   = 1

        system_failure = 2

        OTHERS         = 3.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    ls_main_data-zzreqno            = lv_Req.

    ls_main_data-zzcust_id          = lv_custId.

    ls_main_data-zzlead_name        = ls_payload_data-zzlead_name.

    ls_main_data-zzpreloc           = ls_payload_data-zzpreloc.

    ls_main_data-zzprelocothr          = ls_payload_data-zzprelocothr.

    ls_main_data-zzsourcecode       = ls_payload_data-zzsourcecode.

    ls_main_data-zzcampaigncode     = ls_payload_data-zzcampaigncode.

    ls_main_data-zzservicecode      = ls_payload_data-zzservicecode.

    ls_main_data-zzother_service    = ls_payload_data-zzother_service.

    ls_main_data-zzreference_pernr  = ls_payload_data-zzreference_pernr.
 
    ls_main_data-zzserviceothr      = ls_payload_data-zzserviceothr.

    ls_main_data-zzsourceothr       = ls_payload_data-zzsourceothr.

    ls_main_data-zzothrservicetyp   = ls_payload_data-zzothrservicetyp.
 
 
    ls_main_data-zzcommodityarea    = ls_payload_data-zzcommodityarea.

    ls_main_data-zzbags             = ls_payload_data-zzbags.

    ls_main_data-zztroad_from       = ls_payload_data-zztroad_from.

    ls_main_data-zztroad_to         = ls_payload_data-zztroad_to.

    ls_main_data-zztrail_from       = ls_payload_data-zztrail_from.

    ls_main_data-zztrail_to         = ls_payload_data-zztrail_to.

    ls_main_data-zro                = ls_payload_data-zro.
 
 
    ls_main_data-zzstatus           = lv_status.

    ls_main_data-zzsentto           = lv_pernr.

    ls_main_data-zzchanged_by       = lv_pernr.

    ls_main_data-zzchanged_on       = lv_local_timestamp.

    ls_main_data-zzcreated_by       = lv_pernr.

    ls_main_data-zzcreated_on       = lv_local_timestamp.
 
    data: lv_quan type P LENGTH 10 DECIMALS 2.

    lv_quan = ls_payload_data-zquant.
 
    ls_main_data-zquan = lv_quan. "shubham 13.04.2026
 
    MODIFY ztlo_main FROM ls_main_data.
 
    COMMIT WORK AND WAIT.
 
    CALL FUNCTION 'DEQUEUE_E_TABLE'

      EXPORTING

        mode_rstable = 'E'

        tabname      = 'ZTLO_MAIN'.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    "Modify table ZTLO_WORKFLOW.
 
    CALL FUNCTION 'ENQUEUE_E_TABLE'

      EXPORTING

        mode_rstable   = 'E'

        tabname        = 'ZTLO_WORKFLOW'

      EXCEPTIONS

        foreign_lock   = 1

        system_failure = 2

        OTHERS         = 3.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    ls_workflow_data-zzseqno        = lv_seq.

    ls_workflow_data-zzreqno        = lv_req.

    ls_workflow_data-zzcust_id      = lv_custid.

    ls_workflow_data-zzsentto       = lv_pernr.

    ls_workflow_data-zzstatus       = lv_status.

    ls_workflow_data-zzremarks      = ls_payload_data-zzremarks.

    ls_workflow_data-zzchanged_by   = lv_pernr.

    ls_workflow_data-zzchanged_on   = lv_local_timestamp.
 
    MODIFY ztlo_workflow FROM ls_workflow_data.
 
    COMMIT WORK AND WAIT.
 
    CALL FUNCTION 'DEQUEUE_E_TABLE'

      EXPORTING

        mode_rstable = 'E'

        tabname      = 'ZTLO_WORKFLOW'.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    LOOP AT lt_intruction INTO DATA(ls_instruction).
 
      ls_instruct-zzseqno       = sy-tabix.

      ls_instruct-zzreqno       = lv_Req.

      ls_instruct-zztext        = ls_instruction-zztext.

      ls_instruct-zzoptions     = ls_instruction-zzoptions.

      ls_instruct-zzremarks     = ls_instruction-zzremarks.

      ls_instruct-zzfrom        = ls_instruction-zzfrom.

      ls_instruct-zzto          = ls_instruction-zzto.

      ls_instruct-zzchanged_by  = lv_pernr.

      ls_instruct-zzchanged_on  = lv_local_timestamp.

      APPEND ls_instruct TO lt_instruct.

      CLEAR ls_instruct.

    ENDLOOP.
 
    "Modify table ztlo_cust_inst.
 
    CALL FUNCTION 'ENQUEUE_E_TABLE'

      EXPORTING

        mode_rstable   = 'E'

        tabname        = 'ztlo_cust_inst'

      EXCEPTIONS

        foreign_lock   = 1

        system_failure = 2

        OTHERS         = 3.
 
    IF sy-subrc <> 0.

    ENDIF.
 
 
    MODIFY ztlo_cust_inst FROM TABLE lt_instruct.
 
    COMMIT WORK AND WAIT.
 
    CALL FUNCTION 'DEQUEUE_E_TABLE'

      EXPORTING

        mode_rstable = 'E'

        tabname      = 'ztlo_cust_inst'.
 
    IF sy-subrc <> 0.

    ENDIF.
 
    IF sy-subrc EQ 0.
 
      lv_message_text = |Lead: { lv_req } { COND string(

            WHEN ls_payload_data-action = 'D' THEN 'saved'

            WHEN ls_payload_data-action = 'S' THEN 'created'

            ELSE 'processed') } successfully.|.
 
      CALL METHOD lo_message_container->add_message_text_only

        EXPORTING

          iv_msg_type               = /iwbep/cl_cos_logger=>success

          iv_msg_text               = lv_message_text

          iv_add_to_response_header = abap_true.
 
    ENDIF.
 
    me->copy_data_to_ref(

    EXPORTING

      is_data = ls_payload_data

    CHANGING

      cr_data = er_deep_entity ).
 
 
  ENDMETHOD.
 

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class ZCL_ZWM_TEMP_ADV_DPC_EXT definition
  public
  inheriting from ZCL_ZWM_TEMP_ADV_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_STREAM
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_STREAM
    redefinition .
protected section.

  methods APPROVEDAMOUTSET_GET_ENTITY
    redefinition .
  methods APPROVEDAMOUTSET_GET_ENTITYSET
    redefinition .
  methods ATTACHMENTSET_GET_ENTITYSET
    redefinition .
  methods ATTACHMENTTREQSE_GET_ENTITYSET
    redefinition .
  methods ATTACHMENTVREQSE_GET_ENTITYSET
    redefinition .
  methods DELETEVOUCHERSET_GET_ENTITYSET
    redefinition .
  methods EMPLOYEEDETAILSE_GET_ENTITYSET
    redefinition .
  methods F4_ACTIVITYPERNR_GET_ENTITYSET
    redefinition .
  methods F4_ACTIVITYSET_GET_ENTITYSET
    redefinition .
  methods F4_ACTIVITYVOUCH_GET_ENTITYSET
    redefinition .
  methods F4_ASSETCLASSSET_GET_ENTITYSET
    redefinition .
  methods F4_ASSETSET_GET_ENTITYSET
    redefinition .
  methods F4_BANKLEDGERSET_GET_ENTITYSET
    redefinition .
  methods F4_DIVISIONSET_GET_ENTITYSET
    redefinition .
  methods F4_FIFINALLISTSE_GET_ENTITYSET
    redefinition .
  methods F4_HSNSET_GET_ENTITYSET
    redefinition .
  methods F4_LEDGERSET_GET_ENTITYSET
    redefinition .
  methods F4_PAEMPLOYEELIS_GET_ENTITYSET
    redefinition .
  methods F4_REQNOVOUCHERS_GET_ENTITYSET
    redefinition .
  methods F4_REQUESTNOSET_GET_ENTITYSET
    redefinition .
  methods F4_STATESET_GET_ENTITYSET
    redefinition .
  methods F4_TAXCODESET_GET_ENTITYSET
    redefinition .
  methods F4_UNSPENTBANKLE_GET_ENTITYSET
    redefinition .
  methods FIOVERVIEWSET_GET_ENTITYSET
    redefinition .
  methods LOGREPORTSET_GET_ENTITYSET
    redefinition .
  methods OVERVIEWSET_GET_ENTITYSET
    redefinition .
  methods REJECTREMARKSSET_GET_ENTITYSET
    redefinition .
  methods SERVICERECEIVERS_GET_ENTITYSET
    redefinition .
  methods STATEMENTSET_GET_ENTITYSET
    redefinition .
  methods TEMPADVANCEBOOKS_GET_ENTITYSET
    redefinition .
  methods TEMPADVANCEREPOR_GET_ENTITYSET
    redefinition .
  methods TEMPADVDETAILSET_GET_ENTITYSET
    redefinition .
  methods TEMPADVHEADERSET_GET_ENTITY
    redefinition .
  methods TEMPVOUCHERDETAI_GET_ENTITYSET
    redefinition .
  methods TEMPVOUCHERHEADE_GET_ENTITY
    redefinition .
  methods UNSENTAMTSET_GET_ENTITY
    redefinition .
  methods UNSENTDEPOSITSET_CREATE_ENTITY
    redefinition .
  methods UNSPENTDISPLAYSE_GET_ENTITY
    redefinition .
  methods UNSPENTDISPLAYSE_GET_ENTITYSET
    redefinition .
  methods VENDORSET_CREATE_ENTITY
    redefinition .
  methods VENDORSET_GET_ENTITY
    redefinition .
  methods VENDORSET_GET_ENTITYSET
    redefinition .
  methods VOUCHERACTIONSET_GET_ENTITYSET
    redefinition .
  methods VOUCHERAPPROVERV_GET_ENTITYSET
    redefinition .
  methods VOUCHEROVERVIEWS_GET_ENTITYSET
    redefinition .
  methods VOUCHERSUBMITSET_GET_ENTITYSET
    redefinition .
  methods WALLETSET_GET_ENTITY
    redefinition .
  methods F4_STATUSFILTERS_GET_ENTITYSET
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZWM_TEMP_ADV_DPC_EXT IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ZWM_TEMP_ADV_DPC_EXT->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING(optional)
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING(optional)
* | [--->] IV_SOURCE_NAME                 TYPE        STRING(optional)
* | [--->] IO_DATA_PROVIDER               TYPE REF TO /IWBEP/IF_MGW_ENTRY_PROVIDER
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH(optional)
* | [--->] IO_EXPAND                      TYPE REF TO /IWBEP/IF_MGW_ODATA_EXPAND
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY_C(optional)
* | [<---] ER_DEEP_ENTITY                 TYPE REF TO DATA
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
    DATA: lo_message_container TYPE REF TO /iwbep/if_message_container,
          lv_error_msg         TYPE bapi_msg.


    DATA: lv_seq          TYPE ztwm_temp_log-seqno,
          lv_pernr        TYPE ess_emp-employeenumber,
          lv_message_text TYPE bapi_msg,
          lv_fiscyear     TYPE gjahr,
          lv_error        TYPE abap_bool VALUE abap_false,
          lv_status       TYPE c LENGTH 2,
          lv_uname        TYPE sy-uname.


    CALL METHOD me->/iwbep/if_mgw_conv_srv_runtime~get_message_container
      RECEIVING
        ro_message_container = lo_message_container.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.
    GET TIME STAMP FIELD DATA(lv_local_timestamp).


    IF iv_entity_name = 'TempAdvHeader'.

      DATA: BEGIN OF ls_payload_data.
              INCLUDE TYPE zcl_zwm_temp_adv_mpc=>ts_tempadvheader.
      DATA:   navheadertodetail TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_tempadvdetail.
      DATA: END OF ls_payload_data.

      DATA:  lt_detail   TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_tempadvdetail.


      DATA: lt_ztwm_temp_detail TYPE STANDARD TABLE OF ztwm_temp_detail.



      DATA: ls_ztwm_temp_master TYPE ztwm_temp_master,
            ls_ztwm_temp_detail TYPE ztwm_temp_detail,
            ls_ztwm_temp_log    TYPE ztwm_temp_log.


      TRY.
          io_data_provider->read_entry_data(
            IMPORTING
              es_data = ls_payload_data ).

        CATCH: /iwbep/cx_mgw_tech_exception INTO DATA(lcx_mgw_tech_exception).
      ENDTRY.

      lt_detail = CORRESPONDING #( ls_payload_data-navheadertodetail ).



      CALL FUNCTION 'FI_PERIOD_DETERMINE'
        EXPORTING
          i_periv = 'K4'
          i_budat = sy-datum
        IMPORTING
          e_gjahr = lv_fiscyear
        EXCEPTIONS
          OTHERS  = 1.

      IF ls_payload_data-reqno IS INITIAL.

        SELECT SINGLE FROM ztwm_temp_master
           FIELDS MAX( reqno )
           INTO @DATA(lv_req).

        IF lv_req IS NOT INITIAL.
          IF lv_req(4) = lv_fiscyear.
            lv_req += 1.
          ELSE.
            lv_req = |{ lv_fiscyear }000001|.
          ENDIF.
          CONDENSE lv_req.
        ELSE.
          lv_req = |{ lv_fiscyear }000001|.
        ENDIF.
        lv_seq = '1'.
      ELSE.
        SELECT SINGLE FROM ztwm_temp_log
           FIELDS MAX( seqno )
           WHERE reqno = @ls_payload_data-reqno
           INTO @lv_seq.
        lv_req = ls_payload_data-reqno.
        lv_seq += 1.
      ENDIF.

      IF ls_payload_data-action = 'D'.
        lv_status = '05'.
      ELSE.
        lv_status = '10'.
      ENDIF.

      CALL FUNCTION 'ENQUEUE_E_TABLE'
        EXPORTING
          tabname = 'ZTWM_TEMP_MASTER'
        EXCEPTIONS
          OTHERS  = 1.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.


*       IF ls_payload_data-warehouse = '1000'.
*
*        SELECT SINGLE
*        FROM zthr_dept_head
*        FIELDS
*          uname
*        WHERE department_id = @ls_payload_data-division
*         AND type = '10'
*        INTO @DATA(lv_uname).
*      ELSE.
*        SELECT SINGLE
*        FROM zthr_dept_head
*        FIELDS
*           uname
*        WHERE department_id = @ls_payload_data-division
*          AND type = '20'
*        INTO @lv_uname.
*      ENDIF.


      CALL FUNCTION 'HR_GET_USER_FROM_EMPLOYEE'
        EXPORTING
          pernr              = CONV pernr_d( ls_payload_data-apprpernr )
        IMPORTING
          user               = lv_uname
        EXCEPTIONS
          pernr_inactive     = 1
          pernr_not_assigned = 2
          OTHERS             = 3.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      "----------------- MASTER -----------------

      ls_ztwm_temp_master-reqno           = lv_req.
      ls_ztwm_temp_master-fyear           = ls_payload_data-fyear.
      ls_ztwm_temp_master-warehouse       = ls_payload_data-warehouse.
      ls_ztwm_temp_master-division        = ls_payload_data-division.
      ls_ztwm_temp_master-req_amt         = ls_payload_data-req_amt.
      ls_ztwm_temp_master-appr_amt        = ls_payload_data-req_amt.  "shubham on 31.01.2026
      ls_ztwm_temp_master-rem_amt         = ls_payload_data-req_amt.   "shubham on 31.01.2026
      ls_ztwm_temp_master-activity        = ls_payload_data-activity.
      ls_ztwm_temp_master-status          = ls_payload_data-action.
      ls_ztwm_temp_master-substatus       = ''.
      ls_ztwm_temp_master-pendingwith     = ls_payload_data-apprpernr.
      ls_ztwm_temp_master-created_by      = lv_pernr.
      ls_ztwm_temp_master-created_on      = lv_local_timestamp.
      ls_ztwm_temp_master-updated_by      = lv_pernr.
      ls_ztwm_temp_master-updated_on      = lv_local_timestamp.

      MODIFY ztwm_temp_master FROM ls_ztwm_temp_master.
      IF sy-subrc <> 0.
        lv_error = abap_true.
      ENDIF.

      "----------------- Detail -----------------
      IF lv_error = abap_false.

        LOOP AT lt_detail INTO DATA(ls_details).

          ls_ztwm_temp_detail-reqno       = lv_req.
          ls_ztwm_temp_detail-seqno       = sy-tabix.
          ls_ztwm_temp_detail-warehouse   = ls_details-warehouse.
          ls_ztwm_temp_detail-activity    = ls_details-activity.
          ls_ztwm_temp_detail-hoe         = ls_details-hoe.
          ls_ztwm_temp_detail-amount      = ls_details-amount.
          ls_ztwm_temp_detail-updated_by  = lv_pernr.
          ls_ztwm_temp_detail-updated_on  = lv_local_timestamp.

          APPEND ls_ztwm_temp_detail TO lt_ztwm_temp_detail.
          CLEAR ls_details.
          CLEAR ls_ztwm_temp_detail.

        ENDLOOP.

        MODIFY ztwm_temp_detail FROM TABLE lt_ztwm_temp_detail.
        IF sy-subrc <> 0.
          lv_error = abap_true.
        ENDIF.
      ENDIF.


      "----------------- LOG -----------------
      IF lv_error = abap_false.

        ls_ztwm_temp_log-seqno       = lv_seq.
        ls_ztwm_temp_log-reqno       = lv_req.
        ls_ztwm_temp_log-voucherreq  = ''.
        ls_ztwm_temp_log-status      = ls_payload_data-action.
        ls_ztwm_temp_log-sub_stat    = ''.
        ls_ztwm_temp_log-remarks     = ls_payload_data-remarks.
        ls_ztwm_temp_log-changed_by  = lv_pernr.
        ls_ztwm_temp_log-changed_on  = lv_local_timestamp.

        MODIFY ztwm_temp_log FROM ls_ztwm_temp_log.
        IF sy-subrc <> 0.
          lv_error = abap_true.
        ENDIF.
      ENDIF.

      "----------------------Commit or rollback----------------------------------
      IF lv_error = abap_true.
        ROLLBACK WORK.
*      RETURN.
      ELSE.
        COMMIT WORK AND WAIT.
      ENDIF.

      CALL FUNCTION 'DEQUEUE_E_TABLE'
        EXPORTING
          tabname = 'ZTMDM_AST_MASTER'.


      IF lv_error = abap_false.

        CALL METHOD lo_message_container->add_message_text_only
          EXPORTING
            iv_msg_type               = /iwbep/cl_cos_logger=>success
            iv_msg_text               = | Temporary Advance request: { lv_req } submitted successfully.|
            iv_add_to_response_header = abap_true.
      ELSE.
        CALL METHOD lo_message_container->add_message_text_only
          EXPORTING
            iv_msg_type               = /iwbep/cl_cos_logger=>error
            iv_msg_text               = 'Error while submission.'
            iv_add_to_response_header = abap_true.

      ENDIF.

      me->copy_data_to_ref(
        EXPORTING
          is_data = ls_payload_data
        CHANGING
          cr_data = er_deep_entity ).



      DATA: lv_return_code    TYPE sy-subrc,
            lv_workitem_id    TYPE swr_struct-workitemid,
            lv_wf_triggered   TYPE abap_bool,
            lv_wi_id          TYPE sww_wiid,
            lt_msg            TYPE TABLE OF swr_messag,
            rv_msg_type       TYPE bapi_mtype,
            lv_user_id        TYPE sy-uname,
            ls_vbsegs         TYPE vbsegs,
            ls_vbsegk         TYPE vbsegk,
            lw_fit_workfl_log TYPE zfit_workfl_log,
            gv_vend_name      TYPE pa0001-ename.

      DATA: lt_input_container TYPE STANDARD TABLE OF swr_cont.
      DATA: ls_input_container TYPE  swcont.
*      lv_user_id = 'SHUBHAMSB'.
      lv_user_id = lv_uname.
      APPEND INITIAL LINE TO lt_input_container
                      ASSIGNING FIELD-SYMBOL(<lfs_input_container>).
      <lfs_input_container>-element = 'GV_APPROVER'.
      <lfs_input_container>-value   = |US{ lv_user_id }|.

      APPEND INITIAL LINE TO lt_input_container
      ASSIGNING <lfs_input_container>.
      <lfs_input_container>-element = 'GV_TCODE'.
      <lfs_input_container>-value   = 'ADV'.

      APPEND INITIAL LINE TO lt_input_container
      ASSIGNING <lfs_input_container>.
      <lfs_input_container>-element = 'GV_TITLE'.
      <lfs_input_container>-value   = 'Temporary Advance No.'.

      APPEND INITIAL LINE TO lt_input_container
      ASSIGNING <lfs_input_container>.
      <lfs_input_container>-element = 'GV_DOCUMENT_NO'.
      <lfs_input_container>-value   = lv_req.
      DATA: lv_fy TYPE char4.
      CALL FUNCTION 'GM_GET_FISCAL_YEAR'
        EXPORTING
          i_date = sy-datum
          i_fyv  = 'V3'
        IMPORTING
          e_fy   = lv_fy
*       EXCEPTIONS
*         FISCAL_YEAR_DOES_NOT_EXIST       = 1
*         NOT_DEFINED_FOR_DATE             = 2
*         OTHERS = 3
        .
      IF sy-subrc <> 0.
* Implement suitable error handling here
      ENDIF.


      APPEND INITIAL LINE TO lt_input_container
      ASSIGNING <lfs_input_container>.
      <lfs_input_container>-element = 'GV_YEAR'.
*      <lfs_input_container>-value   = sy-datum+0(4).
      <lfs_input_container>-value   = lv_fy.

*            append initial line to lt_input_container
*    assigning <lfs_input_container>.
*            <lfs_input_container>-element = 'GV_COMPANY_CODE'.
*            <lfs_input_container>-value   = xvbkpf-bukrs.

      APPEND INITIAL LINE TO lt_input_container
      ASSIGNING <lfs_input_container>.
      <lfs_input_container>-element = 'GV_INITIATOR'.
      <lfs_input_container>-value   = |US{ sy-uname }|.

*            append initial line to lt_input_container
*            assigning <lfs_input_container>.
*            <lfs_input_container>-element = 'GV_VEND_NAME'.
*            <lfs_input_container>-value   = gv_vend_name.

      CALL FUNCTION 'SAP_WAPI_START_WORKFLOW'
        EXPORTING
*         task            = 'WS99800007'"'WS99800024'
          task            = 'WS99800024'
          user            = sy-uname
        IMPORTING
          return_code     = lv_return_code
          workitem_id     = lv_workitem_id
        TABLES
          input_container = lt_input_container
          message_lines   = lt_msg.

      IF lv_return_code = 0.
        IF lv_workitem_id IS NOT INITIAL.

          lw_fit_workfl_log-belnr           = lv_req.
          lw_fit_workfl_log-gjahr  = lv_fy.
          lw_fit_workfl_log-w_id   = lv_workitem_id.
          lw_fit_workfl_log-workflow_user = lv_user_id.
          lw_fit_workfl_log-creation_date = sy-datum.
          lw_fit_workfl_log-creation_time = sy-uzeit.
          lw_fit_workfl_log-comments = 'Initiated'.
          lw_fit_workfl_log-initiator = sy-uname.
          lw_fit_workfl_log-workflow_template = 'WS99800024'."'WS99800024'.
          lw_fit_workfl_log-status = '20'.
          lw_fit_workfl_log-transaction_code = 'ADV'.  " ADDED BY SHUBHAM ON 13.09.25
          MODIFY zfit_workfl_log FROM lw_fit_workfl_log.
          DATA: ls_zfit_wf_log TYPE zfit_wf_log.
          ls_zfit_wf_log-belnr = lv_req.
          ls_zfit_wf_log-gjhar = lv_fy.
          ls_zfit_wf_log-forward_to = lv_user_id.

          MODIFY zfit_wf_log FROM ls_zfit_wf_log.
        ENDIF.
      ENDIF.
    ELSEIF  iv_entity_name = 'TempVoucherHeader'.

      CLEAR: lv_seq,
             lv_req,
             lv_fiscyear,
             lv_error,
             lv_status.

      DATA: BEGIN OF ls_voucher_payload_data.
              INCLUDE TYPE zcl_zwm_temp_adv_mpc=>ts_tempvoucherheader.
      DATA:   navvoucherheadertodetail TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_tempvoucherdetail.
      DATA: END OF ls_voucher_payload_data.

      DATA:  lt_ledger   TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_tempvoucherdetail.

      DATA: lt_ztwm_temp_ledger TYPE STANDARD TABLE OF ztwm_temp_ledger.

      DATA: ls_ztwm_temp_vouch  TYPE ztwm_temp_vouch,
            ls_ztwm_temp_ledger TYPE ztwm_temp_ledger,
            ls_ztwm_temp_srv_pr TYPE ztwm_temp_srv_pr.



      TRY.
          io_data_provider->read_entry_data(
            IMPORTING
              es_data = ls_voucher_payload_data ).

        CATCH: /iwbep/cx_mgw_tech_exception INTO lcx_mgw_tech_exception.
      ENDTRY.

      lt_ledger = CORRESPONDING #( ls_voucher_payload_data-navvoucherheadertodetail ).

      CALL FUNCTION 'FI_PERIOD_DETERMINE'
        EXPORTING
          i_periv = 'K4'
          i_budat = sy-datum
        IMPORTING
          e_gjahr = lv_fiscyear
        EXCEPTIONS
          OTHERS  = 1.

      IF ls_voucher_payload_data-reqno IS NOT INITIAL.

        IF ls_voucher_payload_data-voucherno IS INITIAL.

          SELECT SINGLE FROM ztwm_temp_vouch
            FIELDS MAX( voucherreq )
            INTO @DATA(lv_vreq).

          IF lv_vreq IS NOT INITIAL.
            lv_vreq += 1.
          ELSE.
            lv_vreq = '1000000001'.
*           lv_seq = '1'.
          ENDIF.
          CONDENSE lv_req.

        ELSE.

          lv_vreq = ls_voucher_payload_data-voucherno.

          SELECT SINGLE * FROM ztwm_temp_vouch INTO @DATA(ls_vouch_temp)
            WHERE reqno = @ls_voucher_payload_data-reqno AND voucherreq = @ls_voucher_payload_data-voucherno.
        ENDIF.

        SELECT SINGLE FROM ztwm_temp_log
           FIELDS MAX( seqno )
           WHERE reqno = @ls_voucher_payload_data-reqno
           INTO @lv_seq.
        lv_seq += 1.

        CALL FUNCTION 'ENQUEUE_E_TABLE'
          EXPORTING
            tabname = 'ztwm_temp_master'
          EXCEPTIONS
            OTHERS  = 1.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.

        "----------------- MASTER -----------------

        IF ls_vouch_temp-voucherreq IS INITIAL.

          SELECT SINGLE rem_amt,appr_amt FROM ztwm_temp_master WHERE reqno = @ls_voucher_payload_data-reqno INTO @DATA(ls_rem_amt).

          SELECT SUM( voucher_amt ) FROM ztwm_temp_vouch INTO @DATA(lv_total) WHERE reqno = @ls_voucher_payload_data-reqno.

          DATA(lv_rem_amt) = ls_rem_amt-appr_amt - ( lv_total + ls_voucher_payload_data-totalamt ).

        ELSE. "shubham on 20.04.2026

          SELECT SUM( voucher_amt ) FROM ztwm_temp_vouch INTO @lv_total WHERE reqno = @ls_voucher_payload_data-reqno.

          SELECT SINGLE rem_amt,appr_amt FROM ztwm_temp_master
            WHERE reqno = @ls_voucher_payload_data-reqno INTO @ls_rem_amt.

          lv_total = lv_total - ls_vouch_temp-voucher_amt.
          lv_total = lv_total + ls_voucher_payload_data-totalamt.

          lv_rem_amt = ls_rem_amt-appr_amt - lv_total.

          IF lv_total > ls_rem_amt-appr_amt.

            lv_error = abap_true.
            DATA(lv_amount_error) = 'Amount is greater than approved amount'.

          ENDIF.
        ENDIF.
        IF lv_error = abap_false.
          IF ls_vouch_temp  IS NOT INITIAL AND ls_vouch_temp-status EQ '31'.

            UPDATE ztwm_temp_master
            SET status     = @ls_vouch_temp-status,
                rem_amt    = @lv_rem_amt,
                updated_by = @lv_pernr,
                updated_on = @lv_local_timestamp
          WHERE reqno      = @ls_voucher_payload_data-reqno.

            IF sy-subrc IS INITIAL.
              lv_error = abap_false.
            ENDIF.

          ELSE.

            UPDATE ztwm_temp_master
             SET status     = '25',
                 rem_amt    = @lv_rem_amt,
                 updated_by = @lv_pernr,
                 updated_on = @lv_local_timestamp
           WHERE reqno      = @ls_voucher_payload_data-reqno.

            IF sy-subrc IS INITIAL.
              lv_error = abap_false.
            ENDIF.

          ENDIF.

        ENDIF.

        "----------------- Voucher -----------------
        IF lv_error = abap_false.

          ls_ztwm_temp_vouch-reqno                = ls_voucher_payload_data-reqno.
          ls_ztwm_temp_vouch-voucherreq           = lv_vreq.
          ls_ztwm_temp_vouch-fyear                = ls_voucher_payload_data-fiscalyear.
          IF ls_vouch_temp IS NOT INITIAL.
            ls_ztwm_temp_vouch-activity             = ls_vouch_temp-activity.
          ELSE.
            ls_ztwm_temp_vouch-activity             = ls_voucher_payload_data-activity.
          ENDIF.
          ls_ztwm_temp_vouch-tokenno              = ls_voucher_payload_data-reqno.
          ls_ztwm_temp_vouch-appr_amt             = ls_voucher_payload_data-appramt.
          ls_ztwm_temp_vouch-remain_amt           = lv_rem_amt.
          ls_ztwm_temp_vouch-voucher_date         = ls_voucher_payload_data-voucher_date.
          ls_ztwm_temp_vouch-purch_billno         = ls_voucher_payload_data-purch_billno.
          ls_ztwm_temp_vouch-date_of_exp          = ls_voucher_payload_data-date_of_exp.
          ls_ztwm_temp_vouch-exp_ledg_typ         = ls_voucher_payload_data-explegdertype.
          ls_ztwm_temp_vouch-vend_typ             = ls_voucher_payload_data-vendortype.
          ls_ztwm_temp_vouch-is_vend_req          = ls_voucher_payload_data-isvendor.
          ls_ztwm_temp_vouch-vendor               = ls_voucher_payload_data-vendor.
          ls_ztwm_temp_vouch-taxtype              = ls_voucher_payload_data-taxtype.
          ls_ztwm_temp_vouch-voucher_amt          = ls_voucher_payload_data-totalamt.
          IF ls_vouch_temp IS NOT INITIAL.
            ls_ztwm_temp_vouch-status               = ls_vouch_temp-status.
            ls_ztwm_temp_vouch-pendingwith          = ls_vouch_temp-pendingwith.
            ls_ztwm_temp_vouch-updated_by           = ls_vouch_temp-updated_by.  "SHUBHAM ON 26.05.2026
          ls_ztwm_temp_vouch-updated_on           =   ls_vouch_temp-updated_on.   "SHUBHAM ON 26.05.2026
          ELSE.
            ls_ztwm_temp_vouch-status               = '30'.
            ls_ztwm_temp_vouch-pendingwith          = ls_voucher_payload_data-fiapprpernr.
            ls_ztwm_temp_vouch-updated_by           = lv_pernr.
          ls_ztwm_temp_vouch-updated_on           = lv_local_timestamp.
          ENDIF.


          MODIFY ztwm_temp_vouch FROM ls_ztwm_temp_vouch.
          IF sy-subrc <> 0.
            lv_error = abap_true.
          ENDIF.
        ENDIF.
        "----------------- Service Provider -----------------

        IF lv_error = abap_false.

          ls_ztwm_temp_srv_pr-reqno        = ls_voucher_payload_data-reqno.
          ls_ztwm_temp_srv_pr-voucherreq   = lv_vreq.
          ls_ztwm_temp_srv_pr-name         = ls_voucher_payload_data-providername.
          ls_ztwm_temp_srv_pr-state        = ls_voucher_payload_data-providerstate.
          ls_ztwm_temp_srv_pr-gstin        = ls_voucher_payload_data-providergstin.
          ls_ztwm_temp_srv_pr-address      = ls_voucher_payload_data-provideraddress.
          ls_ztwm_temp_srv_pr-pincode      = ls_voucher_payload_data-providerpincode.
          ls_ztwm_temp_srv_pr-updated_by   = lv_pernr.
          ls_ztwm_temp_srv_pr-updated_on   = lv_local_timestamp.

          MODIFY ztwm_temp_srv_pr FROM ls_ztwm_temp_srv_pr.
          IF sy-subrc <> 0.
            lv_error = abap_true.
          ENDIF.
        ENDIF.

        "----------------- Ledger -----------------
        IF lv_error = abap_false.
          DATA: lv_anln1 TYPE anla-anln1.
          LOOP AT lt_ledger INTO DATA(ls_edger).

            IF ls_edger-assetno IS NOT INITIAL.  "shubham on 23.02.2026
              lv_anln1 = |{ ls_edger-assetno ALPHA = IN }|.
*              lv_comp  = <lfs_req>-header-comp_code.
              SELECT SINGLE FROM anla
              FIELDS *
              WHERE bukrs = '1000'
              AND   anln1 = @lv_anln1
*    AND   anln2 = @<lfs_item>-sub_number
              INTO @DATA(ls_anla).
              IF sy-subrc = 0 AND ls_anla IS NOT INITIAL.
                SELECT SINGLE FROM t095
                FIELDS *
                WHERE ktopl = '1000'
                AND   ktogr = @ls_anla-anlkl
                INTO @DATA(ls_t095).
                IF sy-subrc = 0 AND ls_t095 IS NOT INITIAL.
                  ls_edger-legder = ls_t095-ktansw.
                ENDIF.
              ENDIF.
            ENDIF.

            ls_ztwm_temp_ledger-asset =     ls_edger-assetno.
            ls_ztwm_temp_ledger-asset_class_desc = ls_voucher_payload_data-desc.  "shubham on 20.05.2026
            ls_ztwm_temp_ledger-asset_class = ls_voucher_payload_data-assetclass.  "shubham on 20.05.2026
            ls_ztwm_temp_ledger-seqno             = sy-tabix.
            ls_ztwm_temp_ledger-reqno             = ls_voucher_payload_data-reqno.
            ls_ztwm_temp_ledger-voucherreqno      = lv_vreq.
            ls_ztwm_temp_ledger-ledgercode        = ls_edger-legder.
*            ls_ZTWM_TEMP_LEDGER-description = ls_edger-description.
            ls_ztwm_temp_ledger-hsnsaccode        = ls_edger-hsn.
            ls_ztwm_temp_ledger-amount            = ls_edger-amount.
            ls_ztwm_temp_ledger-taxcode           = ls_edger-taxcode.
            ls_ztwm_temp_ledger-percent           = ls_edger-percent.
            ls_ztwm_temp_ledger-amount_gst        = ls_edger-amount_gst.
            ls_ztwm_temp_ledger-updated_by        = lv_pernr.
            ls_ztwm_temp_ledger-updated_on        = lv_local_timestamp.

            APPEND ls_ztwm_temp_ledger TO lt_ztwm_temp_ledger.
            CLEAR ls_edger.
            CLEAR ls_ztwm_temp_ledger.

          ENDLOOP.

          MODIFY ztwm_temp_ledger FROM TABLE lt_ztwm_temp_ledger.
          IF sy-subrc <> 0.
            lv_error = abap_true.
          ENDIF.
        ENDIF.


        "----------------- LOG -----------------
        IF lv_error = abap_false.

          ls_ztwm_temp_log-seqno        = lv_seq.
          ls_ztwm_temp_log-reqno        =  ls_voucher_payload_data-reqno.
          ls_ztwm_temp_log-voucherreq   =  lv_vreq.
          ls_ztwm_temp_log-status       = '30'.
          ls_ztwm_temp_log-sub_stat     = ''.
          ls_ztwm_temp_log-remarks      = ls_voucher_payload_data-remarks.
          ls_ztwm_temp_log-changed_by   = lv_pernr.
          ls_ztwm_temp_log-changed_on   = lv_local_timestamp.

          MODIFY ztwm_temp_log FROM ls_ztwm_temp_log.
          IF sy-subrc <> 0.
            lv_error = abap_true.
          ENDIF.
        ENDIF.

        "----------------------Commit or rollback----------------------------------
        IF lv_error = abap_true.
          ROLLBACK WORK.
*      RETURN.
        ELSE.
          COMMIT WORK AND WAIT.
        ENDIF.

        CALL FUNCTION 'DEQUEUE_E_TABLE'
          EXPORTING
            tabname = 'ZTMDM_AST_MASTER'.


        IF lv_error = abap_false.

          "BOC shubham on 20.04.2026

          SELECT * FROM ztwm_temp_vouch INTO TABLE @DATA(lt_final_vouch)
            WHERE reqno = @LS_VOUCHER_PAYLOAD_DATA-reqno.

          SORT lt_final_vouch BY voucherreq ASCENDING.

          DATA: lv_rem_amnt TYPE dmbtr.

          LOOP AT lt_final_vouch ASSIGNING FIELD-SYMBOL(<lfs_vou>).
            IF sy-tabix = 1.
              <lfs_vou>-remain_amt = <lfs_vou>-appr_amt - <lfs_vou>-voucher_amt.
              lv_rem_amnt = <lfs_vou>-remain_amt.
            ELSE.
              <lfs_vou>-remain_amt = lv_rem_amnt - <lfs_vou>-voucher_amt.
              lv_rem_amnt = <lfs_vou>-remain_amt.
            ENDIF.

          ENDLOOP.

          MODIFY ztwm_temp_vouch FROM TABLE lt_final_vouch.
          COMMIT WORK.

          "EOC shubham on 20.04.2026

          CALL METHOD lo_message_container->add_message_text_only
            EXPORTING
              iv_msg_type               = /iwbep/cl_cos_logger=>success
              iv_msg_text               = | Voucher request: { lv_vreq } submitted successfully for Request Number: { ls_voucher_payload_data-reqno }.|
              iv_add_to_response_header = abap_true.
        ELSE.
          IF lv_amount_error IS INITIAL.
            CALL METHOD lo_message_container->add_message_text_only
              EXPORTING
                iv_msg_type               = /iwbep/cl_cos_logger=>error
                iv_msg_text               = 'Error while submission.'
                iv_add_to_response_header = abap_true.
          ELSE.
            CALL METHOD lo_message_container->add_message_text_only
              EXPORTING
                iv_msg_type               = /iwbep/cl_cos_logger=>error
                iv_msg_text               = 'Amount is greater than approved amount'
                iv_add_to_response_header = abap_true.
          ENDIF.

        ENDIF.

        me->copy_data_to_ref(
          EXPORTING
            is_data = ls_voucher_payload_data
          CHANGING
            cr_data = er_deep_entity ).
*         SELECT SINGLE * FROM ztwm_temp_master INTO @DATA(LS_MAST) WHERE reqno = @ls_voucher_payload_data-reqno.
*        IF ls_voucher_payload_data-warehouse = '1000'.
*        SELECT SINGLE
*        FROM zthr_dept_head
*        FIELDS
*          uname
*        WHERE department_id = @ls_mast-division
*         AND type = '10'
*        INTO @lv_uname.
*      ELSE.
*        SELECT SINGLE
*        FROM zthr_dept_head
*        FIELDS
*           uname
*        WHERE department_id = @ls_mast-division
*          AND type = '20'
*        INTO @lv_uname.
*      ENDIF.
**        lv_user_id = 'ABHISHEKS'.
***           lv_user_id = lv_uname.
**        APPEND INITIAL LINE TO lt_input_container
**                        ASSIGNING <lfs_input_container>.
**        <lfs_input_container>-element = 'GV_APPROVER'.
**        <lfs_input_container>-value   = |US{ lv_user_id }|.
**
**        APPEND INITIAL LINE TO lt_input_container
**        ASSIGNING <lfs_input_container>.
**        <lfs_input_container>-element = 'GV_TCODE'.
**        <lfs_input_container>-value   = 'TEMP_INV'.
**
**        APPEND INITIAL LINE TO lt_input_container
**        ASSIGNING <lfs_input_container>.
**        <lfs_input_container>-element = 'GV_TITLE'.
**        <lfs_input_container>-value   = 'Voucher No.'.
**
**        APPEND INITIAL LINE TO lt_input_container
**        ASSIGNING <lfs_input_container>.
**        <lfs_input_container>-element = 'GV_DOCUMENT_NO'.
**        <lfs_input_container>-value   = lv_vreq.
**
**        APPEND INITIAL LINE TO lt_input_container
**        ASSIGNING <lfs_input_container>.
**        <lfs_input_container>-element = 'GV_YEAR'.
**        <lfs_input_container>-value   = sy-datum+0(4).
**
***            append initial line to lt_input_container
***    assigning <lfs_input_container>.
***            <lfs_input_container>-element = 'GV_COMPANY_CODE'.
***            <lfs_input_container>-value   = xvbkpf-bukrs.
**
**        APPEND INITIAL LINE TO lt_input_container
**        ASSIGNING <lfs_input_container>.
**        <lfs_input_container>-element = 'GV_INITIATOR'.
**        <lfs_input_container>-value   = |US{ sy-uname }|.
**
***            append initial line to lt_input_container
***            assigning <lfs_input_container>.
***            <lfs_input_container>-element = 'GV_VEND_NAME'.
***            <lfs_input_container>-value   = gv_vend_name.
**
**        CALL FUNCTION 'SAP_WAPI_START_WORKFLOW'
**          EXPORTING
***           task            = 'WS99800007'"'WS99800024'
**            task            = 'WS99800024'
**            user            = sy-uname
**          IMPORTING
**            return_code     = lv_return_code
**            workitem_id     = lv_workitem_id
**          TABLES
**            input_container = lt_input_container
**            message_lines   = lt_msg.
**
**        IF lv_return_code = 0.
**          IF lv_workitem_id IS NOT INITIAL.
**
**            lw_FIT_WORKFL_LOG-belnr           = lv_vreq.
**            lw_FIT_WORKFL_LOG-gjahr  = sy-datum+0(4).
**            lw_FIT_WORKFL_LOG-w_id   = lv_workitem_id.
**            lw_FIT_WORKFL_LOG-workflow_user = lv_user_id.
**            lw_FIT_WORKFL_LOG-creation_date = sy-datum.
**            lw_FIT_WORKFL_LOG-creation_time = sy-uzeit.
**            lw_FIT_WORKFL_LOG-comments = 'Initiated'.
**            lw_FIT_WORKFL_LOG-initiator = sy-uname.
**            lw_FIT_WORKFL_LOG-workflow_template = 'WS99800024'."'WS99800024'.
**            lw_FIT_WORKFL_LOG-status = '20'.
**            lw_FIT_WORKFL_LOG-transaction_code = 'TEMP_INV'.  " ADDED BY SHUBHAM ON 13.09.25
**            MODIFY zfit_workfl_log FROM lw_FIT_WORKFL_LOG.
***          DATA: ls_zfit_wf_log TYPE zfit_wf_log.
**            ls_zfit_wf_log-belnr = lv_vreq.
**            ls_zfit_wf_log-gjhar = sy-datum+0(4).
**            ls_zfit_wf_log-forward_to = lv_user_id.
**
**            MODIFY zfit_wf_log FROM ls_zfit_wf_log.
**          ENDIF.
**        ENDIF.

      ENDIF.

    ELSEIF iv_entity_name = 'VoucherLedgerHeader'.

      DATA: BEGIN OF ls_payload_ledger_data.
              INCLUDE TYPE zcl_zwm_temp_adv_mpc=>ts_voucherledgerheader.
      DATA:   navvoucherledgerheadertodetail TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_voucherledgerdetail.
      DATA: END OF ls_payload_ledger_data.

      DATA:  lt_vledger   TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_voucherledgerdetail.
*
*      DATA:  lt_detail   TYPE STANDARD TABLE OF zcl_zwm_temp_adv_mpc=>ts_tempadvdetail.
*
*
*      DATA: lt_ztwm_temp_detail TYPE STANDARD TABLE OF ztwm_temp_detail.

      TRY.
          io_data_provider->read_entry_data(
            IMPORTING
              es_data = ls_payload_ledger_data ).

        CATCH: /iwbep/cx_mgw_tech_exception INTO lcx_mgw_tech_exception.
      ENDTRY.

      lt_vledger = CORRESPONDING #( ls_payload_ledger_data-navvoucherledgerheadertodetail ).
      DATA: lt_led TYPE STANDARD TABLE OF ztwm_temp_ledger.
      LOOP AT lt_vledger ASSIGNING FIELD-SYMBOL(<lfs_vled>).
        SELECT SINGLE * FROM ztwm_temp_ledger INTO @DATA(ls_led) WHERE reqno = @<lfs_vled>-reqno
          AND voucherreqno = @<lfs_vled>-voucherno AND ledgercode = @<lfs_vled>-ledgerno.
        IF sy-subrc = 0.
          ls_led-taxcode = <lfs_vled>-taxcode.
          APPEND ls_led TO lt_led.
          CLEAR: ls_led.
        ENDIF.
      ENDLOOP.

      MODIFY ztwm_temp_ledger FROM TABLE lt_led.
      COMMIT WORK.

      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>success
          iv_msg_text               = | Data Saved successfully|
          iv_add_to_response_header = abap_true.

      me->copy_data_to_ref(
        EXPORTING
          is_data = ls_voucher_payload_data
        CHANGING
          cr_data = er_deep_entity ).

    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->EMPLOYEEDETAILSE_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_EMPLOYEEDETAIL
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD employeedetailse_get_entityset.
***    DATA: lv_pernr  TYPE pernr_d,
***          ls_emp    TYPE zthr_emp_master,
***          ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_employeedetail.
***
***    " Step 1: Get PERNR from PA0105 using sy-uname
***    SELECT SINGLE pernr
***      INTO lv_pernr
***      FROM pa0105
***      WHERE  usrid = sy-uname.
***
***    IF sy-subrc <> 0.
***      " No PERNR found → raise business exception with message
***      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
***        EXPORTING
***          textid  = /iwbep/cx_mgw_busi_exception=>business_error
***          message = |No PERNR found for SAP user { sy-uname }|.
***      RETURN.
***    ENDIF.
***
***    " Step 2: Get employee details from ZTHR_EMP_MASTER
***    SELECT SINGLE *
***      INTO ls_emp
***      FROM zthr_emp_master
***      WHERE pernr = lv_pernr.
***
***    IF sy-subrc = 0.
***      CLEAR ls_entity.
***      ls_entity-pernr          = ls_emp-pernr.
***      ls_entity-emp_name       = ls_emp-emp_name.
***      ls_entity-area_desp      = ls_emp-area_desp.
***      ls_entity-sub_area_desp  = ls_emp-sub_area_desp.
***      ls_entity-position_disc  = ls_emp-position_disc.
***
***      APPEND ls_entity TO et_entityset.
***    ENDIF.

    DATA: lv_pernr TYPE ess_emp-employeenumber.
    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc = 0.
      SELECT
        FROM zthr_emp_master
        FIELDS
          pernr,
          emp_name,
          area_desp,
          area,
          sub_area,
          sub_area_desp,
          position_disc
      WHERE pernr = @lv_pernr
        INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

      IF sy-subrc IS INITIAL.
        SORT et_entityset BY pernr.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_ACTIVITYSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_ACTIVITY
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD f4_activityset_get_entityset.
  TRY.
      SELECT act_code, act_txt
        FROM ztwm_temp_activt
        INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

      IF sy-subrc IS INITIAL.
        SORT et_entityset BY act_txt.
      ENDIF.

    CATCH /iwbep/cx_mgw_busi_exception INTO DATA(lx_busi).

    CATCH /iwbep/cx_mgw_tech_exception INTO DATA(lx_tech).

  ENDTRY.
ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->OVERVIEWSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_OVERVIEW
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD overviewset_get_entityset.

    DATA: lv_pernr TYPE ess_emp-employeenumber.
    DATA : lt_status_val TYPE TABLE OF dd07v.
    DATA: lv_name        TYPE emnam,
          lv_pendingname TYPE emnam,
          lv_aprname type emnam.
    DATA: lt_entityset TYPE zcl_zwm_temp_adv_mpc=>tt_overview,
          ls_entity    TYPE zcl_zwm_temp_adv_mpc=>ts_overview.
    "Domain values for FORM

    CALL FUNCTION 'GET_DOMAIN_VALUES'
      EXPORTING
        domname    = 'ZDOWM_STATUS'
        text       = 'X'
*       FILL_DD07L_TAB        = ' '
      TABLES
        values_tab = lt_status_val.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.


    SELECT  FROM ztmm_plant
     FIELDS
      zwh,
      zwhdesc
      WHERE zwhtype IN ( 'RO', 'CO' )
     INTO TABLE @DATA(lt_plant).
    IF sy-subrc = 0.

    ENDIF.

    SELECT  FROM ztwm_temp_activt
    FIELDS
     act_code,
     act_txt
    INTO TABLE @DATA(lt_activity).
    IF sy-subrc = 0.

    ENDIF.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
      EXPORTING
        person_no    = lv_pernr
      IMPORTING
        name_with_no = lv_name.

    SELECT
      FROM ztwm_temp_master AS a
      INNER JOIN  ztwm_temp_detail AS b ON a~reqno = b~reqno
      FIELDS
      a~reqno,
      a~fyear,
      a~warehouse,
      a~req_amt,
      a~appr_amt AS appramt,
      a~status,
      a~documentno_req AS documentno,
      a~pendingwith,
      a~created_by,
      a~created_on,
      b~activity
      WHERE a~created_by = @lv_pernr
  INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc = 0.
      SORT et_entityset BY reqno DESCENDING.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING reqno.
    ENDIF.
**
**
**
    DATA: lv_belnr TYPE belnr_d,
          lv_fyear TYPE gjahr.
    LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_details>).

        "BOC BY SHUBHAM ON 19.05.2026

      lv_belnr = <lfs_details>-reqno.
      lv_fyear = <lfs_details>-fyear.

      SELECT SINGLE workflow_user ,belnr,gjahr,creation_date, creation_time FROM zfit_workfl_log INTO @DATA(ls_log)
      WHERE belnr = @lv_belnr AND gjahr = @lv_fyear and status = '40'.

      IF sy-subrc = 0.

        clear: lv_pernr.

        CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
          EXPORTING
            username                  = ls_log-workflow_user
          IMPORTING
            employeenumber            = lv_pernr
          EXCEPTIONS
            user_not_found            = 1
            countrygrouping_not_found = 2
            infty_not_found           = 3
            OTHERS                    = 4.
        IF sy-subrc <> 0.
        ENDIF.
        clear: lv_name.
        CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
          EXPORTING
            person_no    = lv_pernr
          IMPORTING
            name_with_no = lv_aprname.

        <lfs_details>-apprby = lv_aprname.

        CONVERT DATE ls_log-creation_date TIME ls_log-creation_time
        INTO TIME STAMP data(ls_timestmp) TIME ZONE sy-zonlo.

      <lfs_details>-appron = ls_timestmp.

      ENDIF.

      "EOC BY SHUBHAM ON 19.05.2026

      DATA(lv_currpernr) = <lfs_details>-created_by.

      CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
        EXPORTING
          person_no    = CONV pernr_d( lv_currpernr )
        IMPORTING
          name_with_no = lv_name.


      DATA(lv_pendinpernr) = <lfs_details>-pendingwith.

      CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
        EXPORTING
          person_no    = CONV pernr_d( lv_pendinpernr )
        IMPORTING
          name_with_no = lv_pendingname.

      <lfs_details>-status          = VALUE #( lt_status_val[ domvalue_l = <lfs_details>-status ]-ddtext OPTIONAL ).
      <lfs_details>-warehouse       = VALUE #( lt_plant[ zwh = <lfs_details>-warehouse ]-zwhdesc OPTIONAL ).
      <lfs_details>-activity        = VALUE #( lt_activity[ act_code = <lfs_details>-activity ]-act_txt OPTIONAL ).
      <lfs_details>-created_by      = lv_name.
      <lfs_details>-pendingwith     = lv_pendingname.
    ENDLOOP.

*    IF et_entityset IS NOT INITIAL. "shubham 31.01.2026
*
*      DELETE et_entityset FROM 6 TO lines( et_entityset ).
*
*    ENDIF.



  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->APPROVEDAMOUTSET_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_APPROVEDAMOUT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD approvedamoutset_get_entity.

  DATA(lv_reqno) = VALUE #( it_key_tab[ name = 'ReqNo' ]-value OPTIONAL ).
  DATA: ls_entity TYPE ztwm_temp_master.

  SELECT SINGLE appr_amt
    FROM ztwm_temp_master
    WHERE reqno = @lv_reqno
    INTO @ls_entity-appr_amt.

  IF sy-subrc = 0.
    er_entity-appr_amt = ls_entity-appr_amt.
  ELSE.
    CLEAR er_entity.
  ENDIF.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->APPROVEDAMOUTSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_APPROVEDAMOUT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD approvedamoutset_get_entityset.

    DATA(lv_req)      = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).

    SELECT appr_amt, rem_amt
    FROM ztwm_temp_master
    WHERE reqno = @lv_req
    INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc IS INITIAL.
      SELECT SUM( voucher_amt ) AS TotalRemAmt
        FROM ztwm_temp_vouch
        WHERE reqno = @lv_req
        INTO @DATA(ls_totalRemAmt).
      IF sy-subrc IS INITIAL.
        LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_entity>).
          <lfs_entity>-totalremamt = <lfs_entity>-appr_amt - ls_totalRemAmt.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_ACTIVITYPERNR_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_ACTIVITYPERNR
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_activitypernr_get_entityset.

    DATA: lv_pernr TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.


    SELECT
      FROM
       ztwm_temp_master AS a
      INNER JOIN ztwm_temp_activt AS b
      ON a~activity = b~act_code
      FIELDS
        a~activity,
        b~act_txt
      WHERE a~created_by = @lv_pernr
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc IS INITIAL.
      SORT et_entityset BY act_txt.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING activity.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_ACTIVITYVOUCH_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_ACTIVITYVOUCHER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_activityvouch_get_entityset.

    DATA: lv_pernr TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.


    SELECT
      FROM
       ztwm_temp_master AS a
      INNER JOIN ztwm_temp_activt AS b
      ON a~activity = b~act_code
      FIELDS
        a~activity,
        b~act_txt
      WHERE a~pendingwith = @lv_pernr
      and a~status = '31'
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc IS INITIAL.
      SORT et_entityset BY act_txt.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING activity.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_DIVISIONSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_DIVISION
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_divisionset_get_entityset.

    DATA(lv_psa)      = VALUE #( it_filter_select_options[ property = 'PSA' ]-select_options[ 1 ]-low OPTIONAL ).

    SELECT
      FROM zthr_dept_head
      FIELDS
       psa,
       department_id,
       department_txt
      WHERE psa = @lv_psa
      AND department_id IS NOT INITIAL
      AND UName IS NOT INITIAL
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc IS INITIAL.
      SORT et_entityset BY department_txt department_id.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING department_id.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_FIFINALLISTSE_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_FIFINALLIST
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_fifinallistse_get_entityset.

    DATA: lv_pernr        TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    SELECT SINGLE
       FROM
       zthr_emp_master
       FIELDS
       Area
       WHERE pernr = @lv_pernr
      INTO @DATA(lv_pa).

    IF sy-subrc IS INITIAL.
      SELECT SINGLE
        FROM
          zthr_dept_head
        FIELDS
          department_id
        WHERE PA = @lv_pa
        AND section_head_type_code = '1010'
        INTO @DATA(lv_dept).
      IF sy-subrc IS INITIAL.
        SELECT
          FROM
          zthr_emp_master
          FIELDS
          pernr,
          emp_name
          WHERE dept = @lv_dept
          AND emp_status = '3'
          AND emp_group = 'M'
          INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
        IF sy-subrc IS INITIAL.
          SORT et_entityset BY emp_name.
          DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING pernr.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_HSNSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_HSN
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method F4_HSNSET_GET_ENTITYSET.

    Select
      from BSEG as a
      inner join T604N as b
      on a~hsn_sac = b~STEUC
      FIELDS
        a~HSN_SAC,
        b~text1
      where b~spras = 'E'
      into CORRESPONDING FIELDS OF table @et_entityset.
     IF sy-subrc is INITIAL.
       sort et_entityset by hsn_sac.
       delete ADJACENT DUPLICATES FROM et_entityset COMPARING hsn_sac.
     ENDIF.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_LEDGERSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_LEDGER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_ledgerset_get_entityset.


    SELECT
          FROM skb1 AS a
          INNER JOIN SKat AS b
          ON a~saknr = b~saknr
          FIELDS
           a~saknr,
           b~txt50
          WHERE a~saknr LIKE '4%'
            AND a~bukrs = '1000'
          INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc IS INITIAL.
      SORT et_entityset BY saknr.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING saknr.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_PAEMPLOYEELIS_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_PAEMPLOYEELIST
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_paemployeelis_get_entityset.

    DATA: lv_pernr        TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    SELECT SINGLE
      FROM
        zthr_emp_master
      FIELDS
        area
      WHERE pernr = @lv_pernr
      INTO @DATA(lv_pa).
    IF sy-subrc IS INITIAL.
      SELECT
        FROM
        zthr_emp_master
        FIELDS
        pernr,
        emp_name
        WHERE area = @lv_pa
        AND emp_status = '3'
        INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
      IF sy-subrc IS INITIAL.
        SORT et_entityset BY emp_name.
        DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING pernr.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_REQNOVOUCHERS_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_REQNOVOUCHER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_reqnovouchers_get_entityset.

    DATA(lv_activity)      = VALUE #( it_filter_select_options[ property = 'Activity' ]-select_options[ 1 ]-low OPTIONAL ).

    DATA: lv_pernr TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc = 0.
      SELECT
        FROM ztwm_temp_vouch
        FIELDS
          reqno
        WHERE pendingwith  = @lv_pernr
          AND activity    = @lv_activity
          AND status      = '31'
       INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
      IF sy-subrc IS INITIAL.
        SORT et_entityset BY reqno DESCENDING.
        DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING reqno.
      ENDIF.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_REQUESTNOSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_REQUESTNO
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_requestnoset_get_entityset.

     DATA(lv_activity)    = VALUE #( it_filter_select_options[ property = 'Activity' ]-select_options[ 1 ]-low OPTIONAL ).
     DATA(lv_action)      = VALUE #( it_filter_select_options[ property = 'Action' ]-select_options[ 1 ]-low OPTIONAL ).
     DATA(lv_entity)      = VALUE #( it_filter_select_options[ property = 'Entity_name' ]-select_options[ 1 ]-low OPTIONAL ).

    DATA: lv_pernr TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc = 0.

      if lv_entity is INITIAL.

      SELECT
        FROM ztwm_temp_master
        FIELDS
          reqno
        WHERE created_by  = @lv_pernr
          and activity    = @lv_activity
          AND status      = '25'
       INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
        IF sy-subrc is INITIAL.
           SORT et_entityset by reqno DESCENDING.
           DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING reqno.
        ENDIF.

        else.

          SELECT
        FROM ztwm_temp_master
        FIELDS
          reqno
        WHERE created_by  = @lv_pernr
          and activity    = @lv_activity
          AND status in ( '25','31','35','30' )
       INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
        IF sy-subrc is INITIAL.
           SORT et_entityset by reqno DESCENDING.
           DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING reqno.
        ENDIF.
          endif.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_STATESET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_STATE
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD f4_stateset_get_entityset.

  SELECT
    a~bland,
    b~bezei
    FROM t005s AS a
    INNER JOIN t005u AS b
      ON a~land1 = b~land1
     AND a~bland = b~bland
    WHERE a~land1 = 'IN'
      AND b~spras = 'E'
    INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

  IF sy-subrc = 0.
    SORT et_entityset BY bezei ASCENDING.
  ENDIF.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_TAXCODESET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_TAXCODE
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_taxcodeset_get_entityset.
    SELECT
      FROM t007a AS a
      INNER JOIN t007s AS b
      ON a~mwskz = b~mwskz
      FIELDS
       a~mwskz,
       b~text1
      WHERE a~KALSM = 'ZTAXIN'
        and a~MWART = 'V'
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc IS INITIAL.
      SORT et_entityset BY mwskz.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING mwskz.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->STATEMENTSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_STATEMENT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD statementset_get_entityset.

    DATA: LS_ENTITY TYPE zcl_zwm_temp_adv_mpc=>ts_statement.
    DATA: lv_pernr TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    SELECT
      FROM ztwm_temp_statmt
      FIELDS
        REQNO,
        activity,
        debit,
        credit,
        updated_on
      WHERE updated_by = @lv_pernr
      INTO TABLE @DATA(LT_STATEMENT).
*      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

      DATA(LT_TEMP) = lt_statement[].
      SORT LT_TEMP BY reqno ASCENDING activity ASCENDING.
      DELETE ADJACENT DUPLICATES FROM LT_TEMP COMPARING REQNO activity.

      LOOP AT LT_TEMP INTO DATA(LS_DATA).

      SELECT SINGLE SUM( A~DEBIT ) AS SUM FROM @LT_STATEMENT AS A WHERE REQNO = @LS_DATA-reqno
                                                          AND ACTIVITY = @LS_DATA-activity
                                                            INTO @DATA(LS_DEBIT).

        SELECT SINGLE SUM( A~CREDIT ) AS SUM FROM @LT_STATEMENT AS A WHERE REQNO = @LS_DATA-reqno
                                                          AND ACTIVITY = @LS_DATA-activity
                                                            INTO @DATA(LS_CREDIT).

          ls_entity-activity = LS_DATA-activity.
          ls_entity-credit = ls_credit.
          ls_entity-debit = ls_debit.
          ls_entity-reqno = LS_DATA-reqno.

          SELECT SINGLE UPDATED_ON FROM ztwm_temp_statmt INTO @DATA(LV_DATE) WHERE reqno = @LS_DATA-reqno
                                                                                    AND seqno = '1'.
          ls_entity-updated_on = lv_date.
           APPEND ls_entity TO et_entityset.
           CLEAR: ls_entity.
      ENDLOOP.

      SORT et_entityset BY updated_on ASCENDING.
      LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_entity>).
        SELECT SINGLE act_txt FROM ztwm_temp_activt WHERE act_code = @<lfs_entity>-activity INTO @DATA(ls_activity).
        <lfs_entity>-activity = ls_activity.
      ENDLOOP.


    SORT et_entityset by updated_on DESCENDING.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->TEMPADVDETAILSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_TEMPADVDETAIL
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD tempadvdetailset_get_entityset.

  DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).

  IF lv_req IS INITIAL.
    RETURN.
  ENDIF.


  TYPES: BEGIN OF ts_tempadvdetail,
           hoe    TYPE string,
           amount TYPE wrbtr,
         END OF ts_tempadvdetail.

  TYPES: tt_tempadvdetail TYPE STANDARD TABLE OF ts_tempadvdetail WITH DEFAULT KEY.

  DATA: lt_tempadvdetail TYPE tt_tempadvdetail.


  SELECT hoe,
         amount
    FROM ztwm_temp_detail
    WHERE reqno = @lv_req
    INTO TABLE @lt_tempadvdetail.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_tempadvdetail ).

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->TEMPADVHEADERSET_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_TEMPADVHEADER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD tempadvheaderset_get_entity.

    DATA(lv_req) = VALUE #( it_key_tab[ name = 'ReqNo' ]-value OPTIONAL ).

    DATA: lv_pernr TYPE ess_emp-employeenumber.
**          lv_name  TYPE emnam.
**
**    DATA: lv_total_amount   TYPE wrbtr,
**          lv_display_amount TYPE string.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    TYPES: BEGIN OF ty_temp_master,
             warehouse TYPE ztwm_temp_master-warehouse,
             division  TYPE ztwm_temp_master-division,
             activity  TYPE ztwm_temp_detail-activity,
           END OF ty_temp_master.

    DATA: ls_entity TYPE ty_temp_master.


    SELECT SINGLE
      FROM ztwm_temp_master AS a
      INNER JOIN ztwm_temp_detail AS b
      ON a~reqno = b~reqno
      FIELDS
        a~warehouse,
        a~division,
        b~activity
      WHERE a~reqno = @lv_req
      INTO @ls_entity.
    IF sy-subrc = 0.
      SELECT SINGLE
        FROM zthr_emp_master
        FIELDS
        sub_area_desp
        WHERE sub_area = @ls_entity-warehouse
        INTO @DATA(ls_psa).
      IF sy-subrc IS INITIAL.

        SELECT SINGLE
        FROM zthr_dept_head
        FIELDS
        department_txt
          WHERE department_id = @ls_entity-division
        INTO @DATA(ls_department).
        IF sy-subrc IS INITIAL.
          SELECT SINGLE
            FROM ztwm_temp_log
            FIELDS
              remarks
            WHERE reqno = @lv_req
            AND status = '10'
            INTO @DATA(lv_remark).
          IF sy-subrc IS INITIAL.
            SELECT SINGLE
              FROM ztwm_temp_activt
              FIELDS
               act_txt
              WHERE act_code = @ls_entity-activity
              INTO @DATA(ls_activity).
            IF sy-subrc IS INITIAL.
              er_entity-activity  = ls_activity.
              er_entity-division  = ls_department.
              er_entity-warehouse = ls_psa.
              er_entity-reqno     = lv_req.
              er_entity-remarks   = lv_remark.
              er_entity-pernr =  lv_pernr.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->TEMPVOUCHERDETAI_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_TEMPVOUCHERDETAIL
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD tempvoucherdetai_get_entityset.

    DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'PSA' ]-select_options[ 1 ]-low OPTIONAL ).

    IF lv_req IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ts_tempvoucherdetail,
             reqno        TYPE string,
             voucherreqno TYPE string,
             legder       TYPE ztwm_temp_ledger-ledgercode,
             hsn          TYPE ztwm_temp_ledger-hsnsaccode,
             assetno      TYPE ztwm_temp_ledger-asset,
             amount       TYPE ztwm_temp_ledger-amount,
             taxcode      TYPE ztwm_temp_ledger-taxcode,
             percent      TYPE ztwm_temp_ledger-percent,
             amount_gst   TYPE ztwm_temp_ledger-amount_gst,
           END OF ts_tempvoucherdetail.

    TYPES: tt_tempvoucherdetail TYPE STANDARD TABLE OF ts_tempvoucherdetail WITH DEFAULT KEY.

    DATA: lt_tempvoucherdetail TYPE tt_tempvoucherdetail.


    SELECT
        reqno,
        voucherreqno,
        ledgercode,
        hsnsaccode,
        asset AS assetno,
        amount,
        taxcode,
        percent,
        amount_gst
      FROM ztwm_temp_ledger
      WHERE voucherreqno = @lv_req
      INTO TABLE @lt_tempvoucherdetail.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    et_entityset = CORRESPONDING #( lt_tempvoucherdetail ).
    IF sy-subrc IS INITIAL.
      LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_entity>).

        select single txt50 from anla INTO @data(lv_txt)
          where anln1 = @<lfs_entity>-assetno.

          if sy-subrc = 0.
            <lfs_entity>-assetedit = |{ <lfs_entity>-assetno }-{ lv_txt }|.
            <lfs_entity>-assetno = |{ <lfs_entity>-assetno }|.
          endif.

        SELECT SINGLE
          FROM skat
          FIELDS
           txt50
          WHERE spras = 'E'
           AND ktopl = '1000'
          AND saknr = @<lfs_entity>-legder
          INTO @DATA(ls_ledger).

        SELECT SINGLE
        FROM t007s
        FIELDS
         text1
        WHERE spras = 'E'
         AND kalsm = 'ZTAXIN'
        AND mwskz = @<lfs_entity>-taxcode
        INTO @DATA(ls_tax).
        <lfs_entity>-ledgerkey = <lfs_entity>-legder.
        <lfs_entity>-legder  = |{ <lfs_entity>-legder } - { ls_ledger }|.

*        <lfs_entity>-taxcode = |{ <lfs_entity>-taxcode } - { ls_tax }|.

        CLEAR: ls_ledger,
              ls_tax.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->TEMPVOUCHERHEADE_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_TEMPVOUCHERHEADER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD tempvoucherheade_get_entity.

    DATA(lv_req) = VALUE #( it_key_tab[ name = 'PSA' ]-value OPTIONAL ).

    DATA: ls_entity TYPE ztwm_temp_vouch.

    SELECT SINGLE
      FROM ztwm_temp_vouch
      FIELDS
        reqno,
        voucherreq,
        fyear,
        activity,
        tokenno,
        appr_amt,
        voucher_amt,
        remain_amt,
        voucher_date,
        purch_billno,
        date_of_exp,
        exp_ledg_typ,
        vend_typ,
        is_vend_req,
        taxtype,
        vendor
      WHERE voucherreq = @lv_req
      INTO CORRESPONDING FIELDS OF @ls_entity.

    IF sy-subrc IS INITIAL.
      SELECT SINGLE
        FROM ztwm_temp_master
        FIELDS
          warehouse
        WHERE reqno = @ls_entity-reqno
        INTO @DATA(lv_warehouse).
      IF sy-subrc IS INITIAL.
        SELECT SINGLE
      FROM zthr_emp_master
      FIELDS
      sub_area_desp
      WHERE sub_area = @lv_warehouse
      INTO @DATA(ls_psa).
        IF sy-subrc IS INITIAL.

          select single * from ztwm_temp_ledger INTO @data(ls_ledger)
             WHERE voucherreqno = @lv_req.
            if ls_ledger-asset is NOT INITIAL.
              select SINGLE ANLKL from anla into @data(lv_class) where anln1 = @ls_ledger-asset.
                select SINGLE TXK50 from ankt INTO @data(lv_class_desc) where anlkl = @lv_class. "shubham on 21.05.2026

            endif.
          SELECT "SINGLE
                  FROM ztwm_temp_log
                  FIELDS
                    remarks,
                    changed_on
                  WHERE voucherreq = @lv_req
                  AND status = '30'
*                  INTO @DATA(lv_remark).
                  INTO TABLE @DATA(lt_remark).
          IF sy-subrc IS INITIAL OR sy-subrc IS NOT INITIAL .
            sort lt_remark by changed_on DESCENDING.
            SELECT SINGLE
              FROM ztwm_temp_activt
              FIELDS
               act_txt
              WHERE act_code = @ls_entity-activity
              INTO @DATA(ls_activity).
            IF sy-subrc IS INITIAL.

              SELECT SINGLE
                FROM ztwm_temp_srv_pr
                FIELDS
                  name,
                  state,
                  gstin,
                  address,
                  pincode
                WHERE voucherreq = @lv_req
                INTO @DATA(ls_srv_prdr).
              IF sy-subrc IS INITIAL.
                SELECT SINGLE BEZEI FROM t005u INTO @DATA(ls_state) WHERE bland = @ls_srv_prdr-state AND land1 = 'IN' AND spras = 'E'.
                IF sy-subrc IS INITIAL.
                  er_entity-activity          = ls_activity.
                  er_entity-appramt           = ls_entity-appr_amt.
                  er_entity-date_of_exp       = ls_entity-date_of_exp.
                  er_entity-purch_billno      = ls_entity-purch_billno.
                  er_entity-explegdertype     = ls_entity-exp_ledg_typ.
                  er_entity-fiscalyear        = ls_entity-fyear.
                  er_entity-isvendor          = ls_entity-is_vend_req.
                  er_entity-provideraddress   = ls_srv_prdr-address.
                  er_entity-providergstin     = ls_srv_prdr-gstin.
                  er_entity-providername      = ls_srv_prdr-name.
                  er_entity-providerpincode   = ls_srv_prdr-pincode.
                  er_entity-providerstate     = ls_srv_prdr-state.
                  er_entity-providerstatetext = ls_state.
                  er_entity-psa               = ls_psa.
                  er_entity-taxtype           = ls_entity-taxtype.
                  er_entity-reqno             = ls_entity-reqno.
*                  er_entity-vendor            = ls_entity-vendor.
                  SELECT SINGLE * from ztwm_temp_vendor INTO @data(ls_vend) where REQNO = @ls_entity-vendor.
                    if sy-subrc = 0.
                       er_entity-vendor            = ls_vend-vendorname.
                    endif.
                  er_entity-vendortype        = ls_entity-vend_typ.
                  er_entity-voucher_date      = ls_entity-voucher_date.
                  er_entity-assetclass      = lv_class.
                  er_entity-desc      = lv_class_desc.

                  READ TABLE lt_remark into data(ls_remark) INDEX 1.
*                  er_entity-remarks           = lv_remark.
                  er_entity-remarks           = ls_remark-remarks.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->UNSENTAMTSET_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_UNSENTAMT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD unsentamtset_get_entity.
    DATA(lv_req) = VALUE #( it_key_tab[ name = 'ReqNo' ]-value OPTIONAL ).

    SELECT SINGLE
      FROM ztwm_temp_master
      FIELDS
        reqno,
        rem_amt
      WHERE reqno = @lv_req
      INTO @er_entity.
    IF sy-subrc IS INITIAL.

    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->UNSENTDEPOSITSET_CREATE_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY_C(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IO_DATA_PROVIDER               TYPE REF TO /IWBEP/IF_MGW_ENTRY_PROVIDER(optional)
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_UNSENTDEPOSIT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD unsentdepositset_create_entity.


    DATA: lo_message_container        TYPE REF TO /iwbep/if_message_container,
          /iwbep/if_message_container.

    DATA : ls_payload_data     TYPE zcl_zwm_temp_adv_mpc=>ts_unsentdeposit.
    DATA : ls_ZTWM_TEMP_UNSENT TYPE ztwm_temp_unsent,
           ls_ZTWM_TEMP_LOG    TYPE ztwm_temp_log,
           ls_ZTWM_TEMP_attach    TYPE ZTWM_TEMP_attach.

    DATA : lv_pernr        TYPE ess_emp-employeenumber,
          lv_pernr1        TYPE ess_emp-employeenumber,
           lv_message_text TYPE bapi_msg.

    DATA : lv_seq         TYPE seqnr_no.
    DATA : lv_status TYPE c LENGTH 2,
           lv_error  TYPE abap_bool VALUE abap_false.

    "get data from payload
    TRY.
        io_data_provider->read_entry_data( IMPORTING es_data = ls_payload_data ).

      CATCH: /iwbep/cx_mgw_tech_exception INTO DATA(lcx_mgw_tech_exception).

    ENDTRY.

    CALL METHOD me->/iwbep/if_mgw_conv_srv_runtime~get_message_container
      RECEIVING
        ro_message_container = lo_message_container.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.

    ENDIF.

    lv_pernr1 = lv_pernr.
    GET TIME STAMP FIELD DATA(lv_local_timestamp).
     DATA(lv_obj)  = NEW zficl_temp_inv_unspent_posting( ).
      DATA: lv_odoc TYPE belnr_d.
      DATA: lv_req TYPE ztwm_temp_master-reqno,
            lv_ledger type ztwm_temp_ledger-ledgercode,
            lv_valdate type ztwm_temp_unsent-value_date, "shubham on 24.03.2026
            lv_unsp_date type ztwm_temp_unsent-voucher_date. "shubham on 21.05.2026
      lv_req = ls_payload_data-reqno.
      lv_ledger = ls_payload_data-ledgercode.
      lv_valdate = ls_payload_data-valdate.
      lv_unsp_date = ls_payload_data-date.  "shubham on 21.05.2026

    SELECT single REM_AMT from ZTWM_TEMP_MASTER into @data(lv_amt) where reqno = @lv_req.

      if lv_amt > 0.


       DATA: ret TYPE zttfi_bapiret.
      "MAIN LOGIC FOR APPROVE
      CALL METHOD lv_obj->approve
        EXPORTING
          req_no = lv_req
          ledger = lv_ledger
          val_date = lv_valdate "shubham on 24.03.2026
          unspnt_date = lv_unsp_date "shubham on 21.05.2026
        IMPORTING
          doc_no =   lv_odoc
        RECEIVING
          return =   ret
        .


      READ TABLE ret INTO DATA(ls_ret) WITH KEY type = 'E'.

      IF sy-subrc ne 0.  "Failed case



    SELECT SINGLE
      FROM ztwm_temp_log
      FIELDS MAX( seqno )
      WHERE reqno = @ls_payload_data-reqno
      INTO @DATA(ls_seq).
    IF ls_seq IS INITIAL.
      lv_seq = '1'.
    ELSE.
      lv_seq = ls_seq + 1.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTWM_TEMP_MASTER'
      EXCEPTIONS
        OTHERS  = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

     "----------------- MASTER -----------------

        UPDATE ztwm_temp_master
           SET
               REM_AMT      = '',
               UNSPENT_AMT  = @ls_payload_data-amount,
               UNSPENT_FLAG = 'X',
               documentno_unsp = @lv_odoc,  "shubham kumar 31.01.2026
               updated_by   = @lv_pernr,
               updated_on   = @lv_local_timestamp
         WHERE reqno        = @ls_payload_data-reqno.

        IF sy-subrc IS INITIAL.
          lv_error = abap_false.
        ENDIF.

        "BOC ADDED BY SHUBHAM ON 26.05.2026

         DATA: ls_ztwm_temp_st TYPE ztwm_temp_statmt.

      SELECT SINGLE * FROM ztwm_temp_master INTO @DATA(ls_master) WHERE reqno = @lv_req.

      SELECT SINGLE
       FROM ztwm_temp_statmt
        FIELDS MAX( seqno )
        WHERE reqno = @ls_master-reqno
        INTO @DATA(lv_seq1).
      IF lv_seq1 IS INITIAL.
        lv_seq1 = '1'.
      ELSE.
        lv_seq1 = lv_seq1 + 1.
      ENDIF.

      ls_ztwm_temp_st-seqno = lv_seq1.
      ls_ztwm_temp_st-reqno = ls_master-reqno.
      ls_ztwm_temp_st-activity = ls_master-activity.
*                 ls_ztwm_temp_st-credit = ls_master-req_amt.
      ls_ztwm_temp_st-credit = ls_payload_data-amount.
      ls_ztwm_temp_st-updated_by = sy-uname.
      GET TIME STAMP FIELD ls_ztwm_temp_st-updated_on .

      MODIFY ztwm_temp_statmt FROM ls_ztwm_temp_st.
      COMMIT WORK.

      "EOC ADDED BY SHUBHAM

    "----------------- UNSENT -----------------

    SELECT MAX( SL_NO ) FROM ztwm_temp_unsent INTO @DATA(LV_SL) WHERE reqno = @ls_payload_data-reqno.

      IF LV_SL IS INITIAL.
        ls_ztwm_temp_unsent-sl_no = 01.
      ELSE.
         ls_ztwm_temp_unsent-sl_no = LV_SL + 1.
      ENDIF.

    ls_ZTWM_TEMP_UNSENT-reqno           = ls_payload_data-reqno.
    ls_ZTWM_TEMP_UNSENT-paytype         = ls_payload_data-paytype.
    ls_ZTWM_TEMP_UNSENT-paymode         = ls_payload_data-paymode.
    ls_ZTWM_TEMP_UNSENT-ledgercode      = ls_payload_data-ledgercode.
    ls_ZTWM_TEMP_UNSENT-amount          = ls_payload_data-amount.
    ls_ZTWM_TEMP_UNSENT-voucher_date    = ls_payload_data-date.
    ls_ZTWM_TEMP_UNSENT-value_date    = ls_payload_data-valdate. "shubham on 24.03.2026
    ls_ZTWM_TEMP_UNSENT-act_code        = ls_payload_data-act_code.
    ls_ZTWM_TEMP_UNSENT-updated_by      = lv_pernr1.
    ls_ZTWM_TEMP_UNSENT-updated_on      = lv_local_timestamp.
*    ls_ZTWM_TEMP_UNSENT-re      = lv_local_timestamp.

    MODIFY ztwm_temp_unsent FROM ls_ZTWM_TEMP_UNSENT.
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.

    IF lv_error = abap_false.

      ls_ZTWM_TEMP_LOG-seqno       = lv_seq.
      ls_ZTWM_TEMP_LOG-reqno       = ls_payload_data-reqno.
      ls_ZTWM_TEMP_LOG-voucherreq  = ''.
      ls_ZTWM_TEMP_LOG-status      = '40'.
      ls_ZTWM_TEMP_LOG-sub_stat    = ''.
      ls_ZTWM_TEMP_LOG-remarks     = ls_payload_data-remark.
      ls_ZTWM_TEMP_LOG-changed_by  = lv_pernr1.
      ls_ZTWM_TEMP_LOG-changed_on  = lv_local_timestamp.

      MODIFY ztwm_temp_log FROM ls_ZTWM_TEMP_LOG.
      IF sy-subrc <> 0.
        lv_error = abap_true.
      ENDIF.



    ENDIF.
    "----------------------Commit or rollback----------------------------------
    IF lv_error = abap_true.
      ROLLBACK WORK.
*      RETURN.
    ELSE.
      COMMIT WORK AND WAIT.
    ENDIF.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTMDM_AST_MASTER'.

  else.
    lv_error = abap_true.
  endif.
    IF lv_error = abap_false.

      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>success
          iv_msg_text               = | Unspent Amount submitted successfully for request: { ls_payload_data-reqno }.|
          iv_add_to_response_header = abap_true.
    ELSE.
      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>error
          iv_msg_text               = 'Error while submission.'
          iv_add_to_response_header = abap_true.

    ENDIF.


    else.

        CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>error
          iv_msg_text               = 'Already unspent deposited'
          iv_add_to_response_header = abap_true.

      endif.





  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VENDORSET_CREATE_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY_C(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IO_DATA_PROVIDER               TYPE REF TO /IWBEP/IF_MGW_ENTRY_PROVIDER(optional)
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_VENDOR
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD vendorset_create_entity.

    DATA: lo_message_container        TYPE REF TO /iwbep/if_message_container,
          /iwbep/if_message_container.

    DATA : ls_payload_data     TYPE zcl_zwm_temp_adv_mpc=>ts_vendor.
    DATA : ls_ZTWM_TEMP_VENDOR TYPE ztwm_temp_vendor.

    DATA : lv_pernr        TYPE ess_emp-employeenumber,
           lv_message_text TYPE bapi_msg.


    DATA : lv_status TYPE c LENGTH 2,
           lv_error  TYPE abap_bool VALUE abap_false.

    TRY.
        io_data_provider->read_entry_data( IMPORTING es_data = ls_payload_data ).

      CATCH: /iwbep/cx_mgw_tech_exception INTO DATA(lcx_mgw_tech_exception).

    ENDTRY.

    CALL METHOD me->/iwbep/if_mgw_conv_srv_runtime~get_message_container
      RECEIVING
        ro_message_container = lo_message_container.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.

    ENDIF.
    GET TIME STAMP FIELD DATA(lv_local_timestamp).

    SELECT SINGLE
      FROM ztwm_temp_vendor
      FIELDS MAX( reqno )
*      WHERE reqno = @ls_payload_data-reqno
      INTO @DATA(lv_req).
    IF lv_req IS INITIAL.
      lv_req = '1000000001'.
    ELSE.
      lv_req = lv_req + 1.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTWM_TEMP_VENDOR'
      EXCEPTIONS
        OTHERS  = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE
      FROM zthr_emp_master
      FIELDS
      area
      WHERE pernr = @lv_pernr
      INTO @DATA(lv_pa).

    "----------------- UNSENT -----------------

    ls_ZTWM_TEMP_VENDOR-reqno        = lv_req.
    ls_ZTWM_TEMP_VENDOR-location     = lv_pa.
    ls_ZTWM_TEMP_VENDOR-vendorname   = ls_payload_data-vendorname.
    ls_ZTWM_TEMP_VENDOR-pincode      = ls_payload_data-pincode.
    ls_ZTWM_TEMP_VENDOR-state        = ls_payload_data-state.
    ls_ZTWM_TEMP_VENDOR-gstin        = ls_payload_data-gstin.
    ls_ZTWM_TEMP_VENDOR-address      = ls_payload_data-address.
    ls_ZTWM_TEMP_VENDOR-updated_by   = lv_pernr.
    ls_ZTWM_TEMP_VENDOR-updated_on   = lv_local_timestamp.

    MODIFY ztwm_temp_vendor FROM ls_ZTWM_TEMP_VENDOR.
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.


    "----------------------Commit or rollback----------------------------------
    IF lv_error = abap_true.
      ROLLBACK WORK.
*      RETURN.
    ELSE.
      COMMIT WORK AND WAIT.
    ENDIF.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTWM_TEMP_VENDOR'.


    IF lv_error = abap_false.

      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>success
          iv_msg_text               = | Vendor created successfully.|
          iv_add_to_response_header = abap_true.
    ELSE.
      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>error
          iv_msg_text               = 'Error while submission.'
          iv_add_to_response_header = abap_true.

    ENDIF.

*    me->copy_data_to_ref(
*     EXPORTING
*       is_data = ls_payload_data
*     CHANGING
*       cr_data = er_entity ).




  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VENDORSET_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_VENDOR
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method VENDORSET_GET_ENTITY.
**TRY.
*CALL METHOD SUPER->VENDORSET_GET_ENTITY
*  EXPORTING
*    IV_ENTITY_NAME          =
*    IV_ENTITY_SET_NAME      =
*    IV_SOURCE_NAME          =
*    IT_KEY_TAB              =
**    io_request_object       =
**    io_tech_request_context =
*    IT_NAVIGATION_PATH      =
**  IMPORTING
**    er_entity               =
**    es_response_context     =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VENDORSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_VENDOR
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD vendorset_get_entityset.

  DATA: lv_pernr TYPE ess_emp-employeenumber.

  CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
    EXPORTING
      username                  = sy-uname
    IMPORTING
      employeenumber            = lv_pernr
    EXCEPTIONS
      user_not_found            = 1
      countrygrouping_not_found = 2
      infty_not_found           = 3
      OTHERS                    = 4.
  IF sy-subrc <> 0.
  ENDIF.

  SELECT SINGLE
    FROM zthr_emp_master
    FIELDS
      area
    WHERE pernr = @lv_pernr
    INTO @DATA(ls_pa).

    SELECT
      FROM ztwm_temp_vendor
      FIELDS
        reqno,
        location,
        vendorname,
        pincode,
        state,
        gstin,
        address
      WHERE LOCATION = @ls_pa
      INTO CORRESPONDING FIELDS OF table @et_entityset.
      IF sy-subrc is INITIAL.
        sort et_entityset by vendorname.
        delete ADJACENT DUPLICATES FROM et_entityset COMPARING reqno.
      ENDIF.
endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VOUCHERACTIONSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_VOUCHERACTION
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD voucheractionset_get_entityset.

    DATA: lv_frontend_message_type TYPE symsgty,
          lv_message_text          TYPE bapi_msg.
    me->/iwbep/if_mgw_conv_srv_runtime~get_message_container(
      RECEIVING
        ro_message_container = DATA(lo_message_container) ).
    DATA: ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_voucheraction.
    DATA(lv_action) = VALUE #( it_filter_select_options[ property = 'Action' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_reqno) = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_voucherreq) = VALUE #( it_filter_select_options[ property = 'VoucherReqNo' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_remarks) = VALUE #( it_filter_select_options[ property = 'Remarks' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_pdate) = VALUE #( it_filter_select_options[ property = 'PostingDate' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA: lv_vou TYPE belnr_d.
    lv_vou = lv_voucherreq.

    "Approve

    IF lv_action  = 'A'.

      SELECT * FROM ztwm_temp_ledger INTO TABLE @DATA(lt_ledger) WHERE voucherreqno = @lv_vou.
      DATA: lv_error TYPE char1,
            lv_msg   TYPE string.
      CLEAR: lv_error.

      SELECT single * from ztwm_temp_vouch INTO @data(ls_vo) where voucherreq = @lv_vou.

      LOOP AT lt_ledger INTO DATA(ls_ledger).
        if ls_vo-vend_typ = '01'.
        IF ls_ledger-taxcode IS INITIAL.
          lv_error = 'E'.
          lv_frontend_message_type = /iwbep/cl_cos_logger=>error.
          lv_msg = |Please enter tax code for ledger - { ls_ledger-ledgercode } in voucher request: { lv_vou }|.
          lv_message_text = lv_msg.
          IF lo_message_container IS BOUND AND lv_frontend_message_type IS NOT INITIAL
                      AND lv_message_text          IS NOT INITIAL.

            lo_message_container->add_message_text_only(
              EXPORTING
                iv_msg_type               = lv_frontend_message_type
                iv_msg_text               = lv_message_text
                iv_add_to_response_header = abap_true ).
          ENDIF.
          EXIT.
        ENDIF.

        endif.

      ENDLOOP.

      IF lv_error = 'E'.
        EXIT.
      ENDIF.

      DATA: ret TYPE zttfi_bapiret.
      DATA: ls_ztwm_temp_log    TYPE ztwm_temp_log.
      DATA(lv_obj)  = NEW zficl_temp_inv_posting( ).
      DATA: lv_odoc TYPE belnr_d.

       DATA lv_yyyymmdd TYPE string.
      lv_yyyymmdd = lv_pdate(8).
      data: lv_post_date type sy-datum.
      lv_post_date = lv_yyyymmdd.

      "MAIN LOGIC FOR APPROVE
      CALL METHOD lv_obj->approve
        EXPORTING
          req_no = lv_vou
          post_date = lv_post_date
        IMPORTING
          doc_no = lv_odoc
        RECEIVING
          return = ret.

      READ TABLE ret INTO DATA(ls_ret) WITH KEY type = 'E'.

      IF sy-subrc = 0.  "Failed case


        lv_frontend_message_type = /iwbep/cl_cos_logger=>error.
        lv_msg = |Document not posted - Error : { ls_ret-message }|.
        lv_message_text = lv_msg.
        IF lo_message_container IS BOUND AND lv_frontend_message_type IS NOT INITIAL
                    AND lv_message_text          IS NOT INITIAL.

          lo_message_container->add_message_text_only(
            EXPORTING
              iv_msg_type               = lv_frontend_message_type
              iv_msg_text               = lv_message_text
              iv_add_to_response_header = abap_true ).

        ENDIF.

        SELECT SINGLE FROM ztwm_temp_log
          FIELDS MAX( seqno )
            WHERE voucherreq = @lv_vou
            INTO @DATA(lv_seq).
        SELECT SINGLE * FROM ztwm_temp_srv_pr INTO @DATA(ls_srv) WHERE voucherreq = @lv_vou.
        lv_seq = lv_seq + 1.
        ls_ztwm_temp_log-seqno       = lv_seq.
        ls_ztwm_temp_log-voucherreq       =  lv_vou.
        ls_ztwm_temp_log-reqno       =  ls_srv-reqno.
*        ls_ztwm_temp_log-status      = '10'.
        ls_ztwm_temp_log-status      = '31'.
        ls_ztwm_temp_log-remarks   = 'Document not posted'.
        ls_ztwm_temp_log-error   = ls_ret-message_v1.

        GET TIME STAMP FIELD DATA(lv_local_timestamp).
        ls_ztwm_temp_log-changed_by  = ''.
        ls_ztwm_temp_log-changed_on  = lv_local_timestamp.

        MODIFY ztwm_temp_log FROM ls_ztwm_temp_log.



      ELSE.  "Success case

        SELECT SINGLE * FROM ztwm_temp_srv_pr INTO @ls_srv WHERE voucherreq = @lv_vou.

        SELECT SINGLE FROM ztwm_temp_log
          FIELDS MAX( seqno )
            WHERE voucherreq = @lv_vou
            INTO @lv_seq.
        lv_seq = lv_seq + 1.
        ls_ztwm_temp_log-seqno       = lv_seq.
        ls_ztwm_temp_log-reqno       =  ls_srv-reqno.
        ls_ztwm_temp_log-voucherreq       =  lv_vou.
        ls_ztwm_temp_log-status      = '35'.
*                  ls_ZTWM_TEMP_LOG-sub_stat    = '10'.

        TRY.
            ls_ztwm_temp_log-remarks   = 'Document Posted'.
          CATCH cx_sy_itab_line_not_found.
        ENDTRY.

        GET TIME STAMP FIELD lv_local_timestamp.
        ls_ztwm_temp_log-changed_by  = ''.
        ls_ztwm_temp_log-changed_on  = lv_local_timestamp.

        MODIFY ztwm_temp_log FROM ls_ztwm_temp_log.
        COMMIT WORK.
        SELECT * FROM ztwm_temp_vouch INTO TABLE @DATA(lt_vou) WHERE reqno = @ls_srv-reqno AND voucherreq = @lv_vou.
        IF lt_vou IS NOT INITIAL.
          LOOP AT lt_vou ASSIGNING FIELD-SYMBOL(<lfs_vou>).
*            <lfs_vou>-remain_amt = <lfs_vou>-remain_amt - <lfs_vou>-voucher_amt.
            <lfs_vou>-flag = 'A'.
            <lfs_vou>-status = '35'.
            IF <lfs_vou>-voucherreq = lv_vou.
              READ TABLE ret INTO ls_ret WITH KEY type = 'S'.
              <lfs_vou>-documentno_vouch = ls_ret-message_v1.
              <lfs_vou>-posting_date = lv_post_date.
            ENDIF.

          ENDLOOP.
          MODIFY ztwm_temp_vouch FROM TABLE lt_vou.
          COMMIT WORK.
        ENDIF.
        SELECT SINGLE * FROM ztwm_temp_vouch INTO  @DATA(ls_temp) WHERE voucherreq = @lv_vou.
        SELECT SINGLE * FROM ztwm_temp_master INTO @DATA(ls_mast) WHERE reqno = @ls_srv-reqno.
*        IF sy-subrc = 0.
*          READ TABLE ret INTO ls_ret WITH KEY type = 'S'.
**                    ls_mast-documentno_vouch = ls_ret-message_v1.
*          ls_mast-rem_amt = ls_mast-rem_amt - ls_temp-voucher_amt.
*          ls_mast-status = '35'.
*          MODIFY ztwm_temp_master FROM ls_mast.
*          COMMIT WORK.
*        ENDIF.

        DATA: ls_ztwm_temp_st TYPE ztwm_temp_statmt.
        CLEAR: lv_seq.
        SELECT SINGLE
         FROM ztwm_temp_statmt
          FIELDS MAX( seqno )
          WHERE reqno = @ls_mast-reqno
          INTO @lv_seq.
        IF lv_seq IS INITIAL.
          lv_seq = '1'.
        ELSE.
          lv_seq = lv_seq + 1.
        ENDIF.
        SELECT SINGLE * FROM ztwm_temp_statmt INTO @DATA(LS_STAT) WHERE reqno = @LS_MAST-reqno.
        ls_ztwm_temp_st-seqno = lv_seq.
        ls_ztwm_temp_st-reqno = ls_mast-reqno.
        ls_ztwm_temp_st-activity = ls_mast-activity.
        ls_ztwm_temp_st-credit = ls_temp-voucher_amt.  "SHUBHAM 26.05.2026
        ls_ztwm_temp_st-updated_by = ls_stat-updated_by.
        GET TIME STAMP FIELD ls_ztwm_temp_st-updated_on .

        MODIFY ztwm_temp_statmt FROM ls_ztwm_temp_st.
        COMMIT WORK.

        DATA(lv_objc)  = NEW zficl_spcl_gl_adjust( ).
        DATA: lv_outdoc TYPE belnr_d.
        DATA: ret_adj TYPE zttfi_bapiret.

        "MAIN LOGIC FOR ADJUSTMENT

        CALL METHOD lv_objc->approve
          EXPORTING
            req_no = lv_vou               " Character Field with Length 10
          IMPORTING
            doc_no = lv_outdoc                " Character Field with Length 10
          RECEIVING
            return = ret_adj.                " Return Parameter


        CALL METHOD lo_message_container->add_message_text_only
          EXPORTING
            iv_msg_type               = /iwbep/cl_cos_logger=>success
            iv_msg_text               = 'Voucher Approved.'
            iv_add_to_response_header = abap_true.


      ENDIF.


      "Reject

    ELSEIF lv_action = 'R'.

      SELECT SINGLE FROM ztwm_temp_log
         FIELDS MAX( seqno )
           WHERE voucherreq = @lv_vou
           INTO @lv_seq.
      SELECT SINGLE * FROM ztwm_temp_srv_pr INTO @ls_srv WHERE voucherreq = @lv_vou.
      lv_seq = lv_seq + 1.
      ls_ztwm_temp_log-seqno       = lv_seq.
      ls_ztwm_temp_log-voucherreq       =  lv_vou.
      ls_ztwm_temp_log-reqno       =  ls_srv-reqno.
      ls_ztwm_temp_log-status      = '36'.
*      ls_ztwm_temp_log-remarks   = 'Document Rejected'.
      ls_ztwm_temp_log-remarks   = lv_remarks. "shubham on 22.05.2026

      GET TIME STAMP FIELD lv_local_timestamp.
      ls_ztwm_temp_log-changed_by  = ''.
      ls_ztwm_temp_log-changed_on  = lv_local_timestamp.

      MODIFY ztwm_temp_log FROM ls_ztwm_temp_log.

      SELECT SINGLE * FROM ztwm_temp_master INTO @ls_mast WHERE reqno = @ls_srv-reqno.
      IF sy-subrc = 0.
        ls_mast-rej_amt = ls_mast-rej_amt + ls_temp-voucher_amt.
        ls_mast-rej_flag = 'X'.
*        ls_mast-rem_amt = ls_mast-rem_amt - ls_temp-voucher_amt.
        MODIFY ztwm_temp_master FROM ls_mast.
        COMMIT WORK.
      ENDIF.

      SELECT SINGLE * FROM ztwm_temp_vouch INTO  @DATA(ls_vou) WHERE reqno = @ls_srv-reqno AND voucherreq = @lv_vou.
      IF sy-subrc = 0.
        ls_vou-flag = 'R'.
        ls_vou-status = '36'.
        MODIFY ztwm_temp_vouch FROM ls_vou.
        COMMIT WORK.
      ENDIF.

      CALL METHOD lo_message_container->add_message_text_only
        EXPORTING
          iv_msg_type               = /iwbep/cl_cos_logger=>success
          iv_msg_text               = 'Voucher rejected.'
          iv_add_to_response_header = abap_true.

    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VOUCHERAPPROVERV_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_VOUCHERAPPROVERVIEW
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD voucherapproverv_get_entityset.

    DATA: ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_voucherapproverview.
    DATA(lv_req)      = VALUE #( it_filter_select_options[ property = 'REQNO' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_activity) = VALUE #( it_filter_select_options[ property = 'ACTIVITY' ]-select_options[ 1 ]-low OPTIONAL ).

    DATA: lv_pernr TYPE ess_emp-employeenumber.
    DATA : lt_status_val TYPE TABLE OF dd07v.
    DATA: lv_name      TYPE emnam,
          lv_initiator TYPE emnam.

    CALL FUNCTION 'GET_DOMAIN_VALUES'
      EXPORTING
        domname    = 'ZDOWM_STATUS'
        text       = 'X'
*       FILL_DD07L_TAB        = ' '
      TABLES
        values_tab = lt_status_val.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT  FROM ztmm_plant
     FIELDS
      zwh,
      zwhdesc
      WHERE zwhtype IN ( 'RO', 'CO' )
     INTO TABLE @DATA(lt_plant).
    IF sy-subrc = 0.

    ENDIF.


    SELECT  FROM ztwm_temp_activt
    FIELDS
     act_code,
     act_txt
    INTO TABLE @DATA(lt_activity).
    IF sy-subrc = 0.

    ENDIF.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
      EXPORTING
        person_no    = lv_pernr
      IMPORTING
        name_with_no = lv_name.

    SELECT *
      FROM ztwm_temp_vouch
      WHERE pendingwith = @lv_pernr
      AND   reqno       = @lv_req
      AND   activity    = @lv_activity
*      AND   flag NOT IN ( 'A' , 'R' )
  INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc = 0.
      SORT et_entityset BY reqno DESCENDING.

    ENDIF.

    SELECT SINGLE created_by FROM ztwm_temp_master INTO @DATA(lv_init) WHERE reqno = @lv_req.

    LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_details>).

*      SELECT SINGLE FROM ztwm_temp_log
*           FIELDS MAX( status )
*          WHERE voucherreq = @<lfs_details>-voucherreq
*           INTO @DATA(lv_status).

      DATA(lv_currpernr) = <lfs_details>-updated_by.

      CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
        EXPORTING
          person_no    = CONV pernr_d( lv_currpernr )
        IMPORTING
          name_with_no = lv_name.

      IF  <lfs_details>-flag = 'A' OR  <lfs_details>-flag = 'R'.
        DATA(lv_flag) = 'X'.
      ELSE.
        lv_flag = ''.
      ENDIF.

      IF  <lfs_details>-flag = 'A'.
        <lfs_details>-flagstatus = 'A'.
      ELSEIF  <lfs_details>-flag = 'R'.
        <lfs_details>-flagstatus = 'R'.
      ENDIF.
      <lfs_details>-status          = VALUE #( lt_status_val[ domvalue_l = <lfs_details>-status ]-ddtext OPTIONAL ).
*      <lfs_details>-warehouse       = VALUE #( lt_plant[ zwh = <lfs_details>-warehouse ]-zwhdesc OPTIONAL ).
      <lfs_details>-flag            = lv_flag.
      <lfs_details>-activity        = VALUE #( lt_activity[ act_code = <lfs_details>-activity ]-act_txt OPTIONAL ).
      <lfs_details>-updated_by      = lv_name.

      CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
        EXPORTING
          person_no    = CONV pernr_d( lv_init )
        IMPORTING
          name_with_no = lv_initiator.
      <lfs_details>-initiator      = lv_initiator.  "shubham on 21.05.2026
    ENDLOOP.


*     SELECT SINGLE * FROM ztwm_temp_unsent
*       INTO @DATA(ls_unspent)
*       WHERE reqno = @lv_req.

    SELECT * FROM ztwm_temp_unsent   "10.06.2026
   INTO TABLE @DATA(lt_unspent)
   WHERE reqno = @lv_req.

*    IF sy-subrc EQ 0 .
    IF lt_unspent IS NOT INITIAL.

      LOOP AT lt_unspent INTO DATA(ls_unspent).

        ls_entity-reqno = ls_unspent-reqno.
        ls_entity-flag = 'X'.
        ls_entity-voucher_amt = ls_unspent-amount.
        DATA lv_yyyymmdd TYPE string.
        lv_yyyymmdd = ls_unspent-voucher_date.
        lv_yyyymmdd = lv_yyyymmdd(8).
        ls_entity-voucher_date = lv_yyyymmdd.
        ls_entity-updated_by = ls_unspent-updated_by.
        ls_entity-updated_on = ls_unspent-updated_on.
        ls_entity-flagstatus = 'U'.

        READ TABLE et_entityset INTO DATA(ls_ent) INDEX 1.
        IF sy-subrc = 0.
          ls_entity-fyear =  ls_ent-fyear.
          ls_entity-activity =  ls_ent-activity.
        ENDIF.

        APPEND ls_entity TO et_entityset.
        CLEAR: ls_entity.

      ENDLOOP.

    ENDIF.


  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VOUCHEROVERVIEWS_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_VOUCHEROVERVIEW
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD voucheroverviews_get_entityset.

    DATA(lv_req)      = VALUE #( it_filter_select_options[ property = 'REQNO' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_activity) = VALUE #( it_filter_select_options[ property = 'ACTIVITY' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA: ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_voucheroverview.
    DATA: lv_pernr TYPE ess_emp-employeenumber.
    DATA : lt_status_val TYPE TABLE OF dd07v.
    DATA: lv_name        TYPE emnam.
    DATA: lv_pname        TYPE emnam.
    DATA: lv_pendname        TYPE emnam.
    DATA: lv_reqno TYPE ztwm_temp_vouch-reqno.

    CALL FUNCTION 'GET_DOMAIN_VALUES'
      EXPORTING
        domname    = 'ZDOWM_STATUS'
        text       = 'X'
*       FILL_DD07L_TAB        = ' '
      TABLES
        values_tab = lt_status_val.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT  FROM ztmm_plant
     FIELDS
      zwh,
      zwhdesc
      WHERE zwhtype IN ( 'RO', 'CO' )
     INTO TABLE @DATA(lt_plant).
    IF sy-subrc = 0.

    ENDIF.

    SELECT  FROM ztwm_temp_activt
    FIELDS
     act_code,
     act_txt
    INTO TABLE @DATA(lt_activity).
    IF sy-subrc = 0.

    ENDIF.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
      EXPORTING
        person_no    = lv_pernr
      IMPORTING
        name_with_no = lv_pname.

    CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
      EXPORTING
        person_no    = lv_pernr
      IMPORTING
        name_with_no = lv_name.


    lv_reqno = lv_req.
    SELECT *
      FROM ztwm_temp_vouch
      WHERE updated_by  = @lv_pernr
      AND activity      = @lv_activity
      AND reqno         = @lv_reqno
  INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

    IF sy-subrc = 0.
      SORT et_entityset BY reqno DESCENDING .
      SORT et_entityset BY voucherreq.
      LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_details>).

        SELECT SINGLE * FROM ztwm_temp_unsent
      INTO @DATA(ls_un)
      WHERE reqno = @lv_reqno.

        IF ls_un IS NOT INITIAL.
          <lfs_details>-unflag = 'X'.
        ENDIF.

*        SELECT SINGLE FROM ztwm_temp_log
*             FIELDS MAX( status )
*            WHERE voucherreq = @<lfs_details>-voucherreq
*             INTO @DATA(lv_status).
        IF <lfs_details>-pendingwith = '00000000' OR <lfs_details>-pendingwith IS INITIAL.

          <lfs_details>-pendingwith = lv_pname.

        ELSE.

          CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
            EXPORTING
              person_no    = CONV pernr_d( <lfs_details>-pendingwith )
            IMPORTING
              name_with_no = lv_pendname.

          <lfs_details>-pendingwith = lv_pendname.

        ENDIF.



        DATA(lv_currpernr) = <lfs_details>-updated_by.


        CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
          EXPORTING
            person_no    = CONV pernr_d( lv_currpernr )
          IMPORTING
            name_with_no = lv_name.
        IF <lfs_details>-status = '31'.
          <lfs_details>-status = 'Approval Pending'.
        ELSE.

          <lfs_details>-status          = VALUE #( lt_status_val[ domvalue_l = <lfs_details>-status ]-ddtext OPTIONAL ).
        ENDIF.
*      <lfs_details>-warehouse       = VALUE #( lt_plant[ zwh = <lfs_details>-warehouse ]-zwhdesc OPTIONAL ).
        <lfs_details>-activity        = VALUE #( lt_activity[ act_code = <lfs_details>-activity ]-act_txt OPTIONAL ).
        <lfs_details>-updated_by      = lv_name.
      ENDLOOP.
    ENDIF.

    SELECT SINGLE * FROM ztwm_temp_unsent
       INTO @DATA(ls_unspent)
       WHERE reqno = @lv_reqno.
    IF sy-subrc EQ 0 .
      ls_entity-reqno = ls_unspent-reqno.
      ls_entity-remain_amt = '0.00'.
*    ls_entity-appr_amt = ls_unspent-amount.
      ls_entity-voucher_amt = ls_unspent-amount.
      DATA lv_yyyymmdd TYPE string.
      lv_yyyymmdd = ls_unspent-voucher_date.
      lv_yyyymmdd = lv_yyyymmdd(8).
      ls_entity-voucher_date = lv_yyyymmdd.
      ls_entity-updated_by = ls_unspent-updated_by.
      ls_entity-updated_on = ls_unspent-updated_on.
      ls_entity-status = 'Unspent Deposited'.
      ls_entity-unflag = 'X'.

      READ TABLE et_entityset INTO DATA(ls_ent) INDEX 1.
      IF sy-subrc = 0.
        ls_entity-fyear =  ls_ent-fyear.
        ls_entity-activity =  ls_ent-activity.
      ENDIF.

      APPEND ls_entity TO et_entityset.
      CLEAR: ls_entity.

    ENDIF.


  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->VOUCHERSUBMITSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_VOUCHERSUBMIT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD vouchersubmitset_get_entityset.
    DATA: lv_frontend_message_type TYPE symsgty,
          lv_message_text          TYPE bapi_msg.
    me->/iwbep/if_mgw_conv_srv_runtime~get_message_container(
      RECEIVING
        ro_message_container = DATA(lo_message_container) ).
    DATA: ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_vouchersubmit.
    DATA(lv_reqno) = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_pend) = VALUE #( it_filter_select_options[ property = 'Pernr' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA: lv_req TYPE belnr_d.
    lv_req = lv_reqno.

    SELECT SINGLE * FROM ztwm_temp_master INTO @DATA(ls_master) WHERE reqno = @lv_req.
    IF sy-subrc = 0.

      IF ls_master-rem_amt NE 0.

        DATA: lv_error TYPE char1,
              lv_msg   TYPE string.
        lv_error = 'E'.
        lv_frontend_message_type = /iwbep/cl_cos_logger=>error.
        lv_msg = |Please deposit unspent remaining amount - { ls_master-rem_amt } |.
        lv_message_text = lv_msg.
        IF lo_message_container IS BOUND AND lv_frontend_message_type IS NOT INITIAL
                    AND lv_message_text          IS NOT INITIAL.

          lo_message_container->add_message_text_only(
            EXPORTING
              iv_msg_type               = lv_frontend_message_type
              iv_msg_text               = lv_message_text
              iv_add_to_response_header = abap_true ).
        ENDIF.
        EXIT.
      ELSE.
        DATA: ls_ztwm_temp_log    TYPE ztwm_temp_log.
        SELECT SINGLE FROM ztwm_temp_log
   FIELDS MAX( seqno )
     WHERE reqno = @lv_req
     INTO @DATA(lv_seq).
        lv_seq = lv_seq + 1.
        ls_ztwm_temp_log-seqno       = lv_seq.
        ls_ztwm_temp_log-reqno       =  lv_req.
*        ls_ztwm_temp_log-voucherreq       =  lv_vou.
        ls_ztwm_temp_log-status      = '31'.
*                  ls_ZTWM_TEMP_LOG-sub_stat    = '10'.

        ls_ztwm_temp_log-remarks   = 'Voucher Request submitted'.
        DATA: lv_pernr        TYPE ess_emp-employeenumber.
        CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
          EXPORTING
            username                  = sy-uname
          IMPORTING
            employeenumber            = lv_pernr
          EXCEPTIONS
            user_not_found            = 1
            countrygrouping_not_found = 2
            infty_not_found           = 3
            OTHERS                    = 4.
        IF sy-subrc <> 0.
        ENDIF.
        GET TIME STAMP FIELD DATA(lv_local_timestamp).
        ls_ztwm_temp_log-changed_by  = lv_pernr.
        ls_ztwm_temp_log-changed_on  = lv_local_timestamp.


        MODIFY ztwm_temp_log FROM ls_ztwm_temp_log.
        COMMIT WORK.
        SELECT * FROM ztwm_temp_vouch INTO TABLE @DATA(lt_vou) WHERE reqno = @lv_req.
        IF lt_vou IS NOT INITIAL.
          LOOP AT lt_vou ASSIGNING FIELD-SYMBOL(<lfs_vou>).
            <lfs_vou>-pendingwith = lv_pend.
            <lfs_vou>-updated_by = lv_pernr.
            <lfs_vou>-updated_on = lv_local_timestamp.

            if <lfs_vou>-status ne '35'. "10.06.2026
            <lfs_vou>-status = '31'.
            endif.

          ENDLOOP.
          MODIFY ztwm_temp_vouch FROM TABLE lt_vou.
          COMMIT WORK.
        ENDIF.

        SELECT SINGLE * FROM ztwm_temp_master INTO @DATA(ls_mast) WHERE reqno = @lv_req.
        IF sy-subrc = 0.
          ls_mast-updated_by = lv_pernr.
          ls_mast-updated_on = lv_local_timestamp.
          ls_mast-status = '31'.
          ls_mast-pendingwith = lv_pend.
          MODIFY ztwm_temp_master FROM ls_mast.
          COMMIT WORK.
        ENDIF.


        DATA: ls_mailbody  TYPE soli,
              lt_mailbody  TYPE bcsy_text,
              it_recipient TYPE ztthr_common_email_recipients,
              ls_recipient TYPE zshr_common_email_recipients,
              iv_commit    TYPE flag VALUE 'X',
              iv_html      TYPE char01 VALUE 'X',
              lc_x(1)      TYPE c VALUE 'X',
              lv_string    TYPE string,
              lv_index     TYPE i.

        DATA: cs_mail_params  TYPE zshr_mail_variable_out.

        DATA(lt_lines) = VALUE tline_tab( ).
        DATA(lv_name) = VALUE thead-tdname( ).

        DATA: lv_sender TYPE ad_smtpadr.
        DATA: lv_mail_flag TYPE char1.


        SELECT * FROM pa0105
        WHERE subty = '0010'
        AND pernr = @lv_pend
        AND begda LE @sy-datum
        AND endda GE @sy-datum
        INTO TABLE @DATA(lt_email).

    "BOC ADDED BY SHUBHAM ON 22.05.2026

        lv_sender = 'notifications@erpcwc.com'.
        IF lt_email IS NOT INITIAL.
          SORT lt_email BY begda endda DESCENDING.
          READ TABLE lt_email INTO DATA(ls_email1) INDEX 1.
          ls_recipient-email_address = ls_email1-usrid_long.
          APPEND ls_recipient TO it_recipient.
          CLEAR: ls_recipient.

*               DATA(lv_ename) = ls_email1-ename.

        ENDIF.
        DATA: lv_subject  TYPE string.
        CONCATENATE 'Tempory advance' ls_mast-reqno 'approval.'
                  INTO lv_subject SEPARATED BY ''.
*
        lt_mailbody = VALUE #(
                              ( line = 'Dear Sir/Madam,<br>' )
                              ( line = ' <br>' )
                              ( line = |Temporary advance vouchers has been submitted for your action.<br>| )
                              ( line = ' <br>' )
                              ( line = |Please take neccessary action<br>| )
                              ( line = ' <br>' )
                              ( line = ' <br>' )
                              ( line = |Details are as follows:<br>| )
                              ( line = ' <br>' )
                              ( line = |Req No.              : { ls_mast-reqno }<br>| )
                              ( line = |Subject         : { lv_subject }<br>| )
*                          ( line = |{ lv_comment }| )
                              ( line = ' ' )
                              ( line = ' ' )
                              ( line = ' ' )
                              ( line = '************************************************************************************<br>' )
                              ( line = |Note: Please DO NOT REPLY! This is an Auto Generated mail alert from Release System.<br>| )
                              ( line = '************************************************************************************<br>' )
                             ).

        CALL METHOD zgclhr_common_utility=>send_mail
          EXPORTING
            iv_subject            = lv_subject
            it_mail_body          = lt_mailbody                 " Text Table
*           it_attachment         = it_attachment                " E-mail Attachment
            it_recipient          = it_recipient                 " E-mail Recipients
            iv_commit             = iv_commit               " General Flag
            iv_sender             = lv_sender                 " E-Mail Address
            iv_html               = iv_html                " Character Field of Length 1
*           iv_send_immediate     =
          IMPORTING
            ev_msgtext            = DATA(lv_msgtext)                " Message Text
            ev_result             = DATA(lv_result1)               " Boolean
          EXCEPTIONS
            exc_create_persistent = 1
            exc_create_document   = 2
            exc_subject_error     = 3
            exc_add_attachment    = 4
            exc_set_document      = 5
            exc_sender_error      = 6
            exc_recipient_error   = 7
            exc_send_error        = 8
            OTHERS                = 9.
        IF sy-subrc <> 0.
*           MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*             WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
        ENDIF.


        "EOC ADDED BY SHUBHAM ON 22.05.2026


        CALL METHOD lo_message_container->add_message_text_only
          EXPORTING
            iv_msg_type               = /iwbep/cl_cos_logger=>success
            iv_msg_text               = | Temporary Advance request: { lv_req } submitted successfully.|
            iv_add_to_response_header = abap_true.


      ENDIF.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->WALLETSET_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_WALLET
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD walletset_get_entity.

    DATA(lv_psa) = VALUE #( it_key_tab[ name = 'PSA' ]-value OPTIONAL ).

    DATA: lv_pernr TYPE ess_emp-employeenumber,
          lv_name  TYPE emnam.

    DATA: lv_total_amount   TYPE wrbtr,
          lv_display_amount TYPE string.

    DATA: ls_entity TYPE zthr_emp_master-sub_area_desp.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
      EXPORTING
        person_no    = CONV pernr_d( lv_pernr )
      IMPORTING
        name_with_no = lv_name.

    SELECT SINGLE
      FROM zthr_emp_master
      FIELDS
       sub_area_desp
      WHERE pernr = @lv_pernr
      INTO @ls_entity.
    IF sy-subrc = 0.
      SELECT SUM( credit )
     FROM ztwm_temp_statmt
     WHERE updated_by = @lv_pernr
     INTO @DATA(lv_credit).
      IF sy-subrc = 0.
        SELECT SUM( debit )
            FROM ztwm_temp_statmt
            WHERE updated_by = @lv_pernr
            INTO @DATA(lv_debit).
        IF sy-subrc = 0.
          lv_total_amount = lv_credit - lv_debit.

          IF sy-subrc IS INITIAL.
            er_entity-ename     = lv_name.
            er_entity-sub_area  = ls_entity.
            er_entity-balance   = lv_total_amount.
          ELSE.
            CLEAR er_entity.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ZWM_TEMP_ADV_DPC_EXT->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_STREAM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING(optional)
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING(optional)
* | [--->] IV_SOURCE_NAME                 TYPE        STRING(optional)
* | [--->] IS_MEDIA_RESOURCE              TYPE        TY_S_MEDIA_RESOURCE
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH(optional)
* | [--->] IV_SLUG                        TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY_C(optional)
* | [<---] ER_ENTITY                      TYPE REF TO DATA
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD /iwbep/if_mgw_appl_srv_runtime~create_stream.

    DATA: lv_file         TYPE string,
          lv_solix_length TYPE i,
          lt_content      TYPE TABLE OF tbl1024, "content OF FILE STORAGE.
          gv_out          TYPE sapb-length,
          lv_extensions   TYPE toadv-doc_type.

    DATA: lv_arc_doc_id TYPE saeardoid.
    DATA: lv_objectid TYPE sapb-sapobjid.

    DATA: lt_content1 TYPE solix_tab,
          lt_data     TYPE soli_tab,
          lt_objhead  TYPE STANDARD TABLE OF soli,
          lt_binrel   TYPE  gbinrel,
          ls_object   TYPE borident,
          ls_obj_data TYPE sood1,
          ls_objhead  TYPE soli,
          ls_fol_id   TYPE soodk,
          ls_obj_id   TYPE soodk,
          ls_folmem_k TYPE sofmk, "folder content DATA
          ls_note     TYPE borident. " bor OBJECT IDENTIFIER..

    DATA: lv_ep_note    TYPE borident-objkey. "“bor OBJECT KEY
    DATA: lv_reqno      TYPE reqno,
*          lv_reqno      TYPE ztwm_temp_attach-reqno,
          lv_vouchReq   TYPE ZTWM_TEMP_vouch-voucherreq,
          ls_attachment TYPE ztwm_temp_attach.

    " Instantiate the Message Container
    DATA: lo_msg TYPE REF TO /iwbep/if_message_container.
    DATA: lo_message_container TYPE REF TO /iwbep/if_message_container.
    DATA: lv_object_id TYPE sapb-sapobjid.

    DATA: lt_components TYPE STANDARD TABLE OF http_comp.
    DATA: lv_file2 TYPE toaat-filename.

    CONSTANTS:
      lc_archivid    TYPE toaar-archiv_id VALUE 'ZC',     "Content-Repository
      lc_arobject    TYPE toaom-ar_object VALUE 'ZDT_TA',
      lc_sapobject   TYPE toaom-sap_object VALUE 'ZBO_TA',
      lc_sapobject_V TYPE toaom-sap_object VALUE 'ZBO_TA_V',
      lc_descr       TYPE toaat-descr VALUE 'BUS',
      lc_doctype     TYPE toadd-doc_type VALUE '*',
      lc_objtyp      TYPE swo_objtyp VALUE 'MESSAGE'.


    GET TIME STAMP FIELD DATA(lv_local_timestamp).

    CALL METHOD zgclhr_common_utility=>get_logged_employee
      EXPORTING
        iv_usrid = CONV #( sy-uname )
      IMPORTING
        ev_pernr = DATA(lv_login_pernr)
      EXCEPTIONS
        retcd    = 1
        OTHERS   = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception.
    ENDIF.

    IF iv_slug IS NOT INITIAL.
      SPLIT iv_slug AT '/' INTO DATA(lv_req) DATA(lv_file_name) DATA(lv_flag).
      lv_file = lv_file_name.
      lv_reqno = lv_req.
    ENDIF.

    IF iv_entity_name = 'AttachmentTReq'.

      CLEAR: lv_extensions.

      IF sy-subrc = 0.
        gv_out        = lv_solix_length.

        DATA(p_file_rev) = reverse( lv_file ).
        SPLIT p_file_rev AT '\' INTO DATA(fname) DATA(rest).
        DATA(p_file_fin) = reverse( fname ).
        DATA(extension_rev) = reverse( p_file_fin ).
        SPLIT extension_rev AT '.' INTO DATA(ext) DATA(rest_ext).
        DATA(ext_fin) = reverse( ext ).

        lv_extensions = ext_fin.

        TRANSLATE lv_extensions TO UPPER CASE.

        lv_objectid = 'TA' && |_| && lv_reqno.

        lv_file2 = lv_file.

      ENDIF.

      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'             " Convert file content from string to Binary
        EXPORTING
*         buffer        = CONV xstring( is_media_resource-value )
          buffer        = is_media_resource-value
        IMPORTING
          output_length = lv_solix_length
        TABLES
          binary_tab    = lt_content. "binary.

      IF sy-subrc = 0.
        gv_out        = lv_solix_length.

        CALL FUNCTION 'ARCHIVOBJECT_CREATE_TABLE'
          EXPORTING
            archiv_id                = lc_archivid
            document_type            = lv_extensions
            length                   = gv_out
          IMPORTING
            archiv_doc_id            = lv_arc_doc_id
          TABLES
            binarchivobject          = lt_content
            components               = lt_components
          EXCEPTIONS
            error_archiv             = 1
            error_communicationtable = 2
            error_kernel             = 3
            OTHERS                   = 4.



        CALL FUNCTION 'ARCHIV_CONNECTION_INSERT'
          EXPORTING
            archiv_id             = lc_archivid
            arc_doc_id            = lv_arc_doc_id
            ar_object             = lc_arobject
            object_id             = lv_objectid
            sap_object            = lc_sapobject
            doc_type              = lv_extensions
            filename              = lv_file2
            descr                 = lc_descr
            creator               = sy-uname
          EXCEPTIONS
            error_connectiontable = 1
            OTHERS                = 2.


        "Modify table ZTLO_M_CUSTOMER.

        CALL FUNCTION 'ENQUEUE_E_TABLE'
          EXPORTING
            mode_rstable   = 'E'
            tabname        = 'ztwm_temp_attach'
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.

        IF sy-subrc <> 0.
        ENDIF.

        ls_attachment-reqno         = lv_req.
        ls_attachment-doc_id        = lv_arc_doc_id.
        ls_attachment-reqtype       = 'T'.
        ls_attachment-file_name     = lv_file_name.
        ls_attachment-mime_type     = is_media_resource-mime_type.
        ls_attachment-content       = is_media_resource-value.
        ls_attachment-updated_on    = lv_local_timestamp.
        ls_attachment-updated_by    = lv_login_pernr.

        MODIFY ztwm_temp_attach FROM ls_attachment.

        COMMIT WORK AND WAIT.

        CALL FUNCTION 'DEQUEUE_E_TABLE'
          EXPORTING
            mode_rstable = 'E'
            tabname      = 'ztwm_temp_attach'.

        IF sy-subrc <> 0.
        ENDIF.
      ENDIF.
    ELSEIF iv_entity_name = 'AttachmentVReq'.
      CLEAR: lv_extensions.

      IF sy-subrc = 0.
        gv_out        = lv_solix_length.

        p_file_rev = reverse( lv_file ).
        SPLIT p_file_rev AT '\' INTO fname rest.
        p_file_fin = reverse( fname ).
        extension_rev = reverse( p_file_fin ).
        SPLIT extension_rev AT '.' INTO ext rest_ext.
        ext_fin = reverse( ext ).

        lv_extensions = ext_fin.

        TRANSLATE lv_extensions TO UPPER CASE.

        lv_objectid = 'VR' && |_| && lv_reqno.

        lv_file2 = lv_file.

      ENDIF.

      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'             " Convert file content from string to Binary
        EXPORTING
*         buffer        = CONV xstring( is_media_resource-value )
          buffer        = is_media_resource-value
        IMPORTING
          output_length = lv_solix_length
        TABLES
          binary_tab    = lt_content. "binary.

      IF sy-subrc = 0.
        gv_out        = lv_solix_length.

        CALL FUNCTION 'ARCHIVOBJECT_CREATE_TABLE'
          EXPORTING
            archiv_id                = lc_archivid
            document_type            = lv_extensions
            length                   = gv_out
          IMPORTING
            archiv_doc_id            = lv_arc_doc_id
          TABLES
            binarchivobject          = lt_content
            components               = lt_components
          EXCEPTIONS
            error_archiv             = 1
            error_communicationtable = 2
            error_kernel             = 3
            OTHERS                   = 4.



        CALL FUNCTION 'ARCHIV_CONNECTION_INSERT'
          EXPORTING
            archiv_id             = lc_archivid
            arc_doc_id            = lv_arc_doc_id
            ar_object             = lc_arobject
            object_id             = lv_objectid
            sap_object            = lc_sapobject_V
            doc_type              = lv_extensions
            filename              = lv_file2
            descr                 = lc_descr
            creator               = sy-uname
          EXCEPTIONS
            error_connectiontable = 1
            OTHERS                = 2.



        "Modify table ZTLO_M_CUSTOMER.

        CALL FUNCTION 'ENQUEUE_E_TABLE'
          EXPORTING
            mode_rstable   = 'E'
            tabname        = 'ztwm_temp_attach'
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.

        IF sy-subrc <> 0.
        ENDIF.

        ls_attachment-reqno         = lv_req.
        ls_attachment-doc_id        = lv_arc_doc_id.
        ls_attachment-reqtype       = 'V'.
        ls_attachment-file_name     = lv_file_name.
        ls_attachment-mime_type     = is_media_resource-mime_type.
        ls_attachment-content       = is_media_resource-value.
        ls_attachment-updated_on    = lv_local_timestamp.
        ls_attachment-updated_by    = lv_login_pernr.

        MODIFY ztwm_temp_attach FROM ls_attachment.

        COMMIT WORK AND WAIT.

        CALL FUNCTION 'DEQUEUE_E_TABLE'
          EXPORTING
            mode_rstable = 'E'
            tabname      = 'ztwm_temp_attach'.

        IF sy-subrc <> 0.
        ENDIF.

      ENDIF.
*    ELSEIF iv_entity_name = 'AttachmentUReq'.
    ELSEIF iv_entity_name = 'Attachment'.

      CLEAR: lv_extensions.

      IF sy-subrc = 0.
        gv_out        = lv_solix_length.
        p_file_rev = reverse( lv_file ).
        SPLIT p_file_rev AT '\' INTO fname rest.
        p_file_fin = reverse( fname ).
        extension_rev = reverse( p_file_fin ).
        SPLIT extension_rev AT '.' INTO ext rest_ext.
        ext_fin = reverse( ext ).

        lv_extensions = ext_fin.

        TRANSLATE lv_extensions TO UPPER CASE.

        lv_objectid = 'UN' && |_| && lv_reqno.

        lv_file2 = lv_file.
      ENDIF.
      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'             " Convert file content from string to Binary
        EXPORTING
*         buffer        = CONV xstring( is_media_resource-value )
          buffer        = is_media_resource-value
        IMPORTING
          output_length = lv_solix_length
        TABLES
          binary_tab    = lt_content. "binary.

      IF sy-subrc = 0.
        gv_out        = lv_solix_length.

        CALL FUNCTION 'ARCHIVOBJECT_CREATE_TABLE'
          EXPORTING
            archiv_id                = lc_archivid
            document_type            = lv_extensions
            length                   = gv_out
          IMPORTING
            archiv_doc_id            = lv_arc_doc_id
          TABLES
            binarchivobject          = lt_content
            components               = lt_components
          EXCEPTIONS
            error_archiv             = 1
            error_communicationtable = 2
            error_kernel             = 3
            OTHERS                   = 4.

        CALL FUNCTION 'ARCHIV_CONNECTION_INSERT'
          EXPORTING
            archiv_id             = lc_archivid
            arc_doc_id            = lv_arc_doc_id
            ar_object             = lc_arobject
            object_id             = lv_objectid
            sap_object            = lc_sapobject
            doc_type              = lv_extensions
            filename              = lv_file2
            descr                 = lc_descr
            creator               = sy-uname
          EXCEPTIONS
            error_connectiontable = 1
            OTHERS                = 2.

        "Modify table ZTLO_M_CUSTOMER.

        CALL FUNCTION 'ENQUEUE_E_TABLE'
          EXPORTING
            mode_rstable   = 'E'
            tabname        = 'ztwm_temp_attach'
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.

        IF sy-subrc <> 0.
        ENDIF.

        ls_attachment-reqno         = lv_req.
        ls_attachment-doc_id        = lv_arc_doc_id.
        ls_attachment-reqtype       = 'U'.
        ls_attachment-file_name     = lv_file_name.
        ls_attachment-mime_type     = is_media_resource-mime_type.
        ls_attachment-content       = is_media_resource-value.
        ls_attachment-updated_on    = lv_local_timestamp.
        ls_attachment-updated_by    = lv_login_pernr.

        MODIFY ztwm_temp_attach FROM ls_attachment.
        COMMIT WORK AND WAIT.
        CALL FUNCTION 'DEQUEUE_E_TABLE'
          EXPORTING
            mode_rstable = 'E'
            tabname      = 'ztwm_temp_attach'.
        IF sy-subrc <> 0.
        ENDIF.
      ENDIF.

    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ZWM_TEMP_ADV_DPC_EXT->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_STREAM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING(optional)
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING(optional)
* | [--->] IV_SOURCE_NAME                 TYPE        STRING(optional)
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [<---] ER_STREAM                      TYPE REF TO DATA
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD /iwbep/if_mgw_appl_srv_runtime~get_stream.
    " Get IDs from keys
    DATA(lv_docid) = VALUE #( it_key_tab[ name = 'DOC_ID' ]-value OPTIONAL ).

    TYPES: tt_toaat TYPE STANDARD TABLE OF toaat WITH DEFAULT KEY.

    DATA : rv_mime_type TYPE mimetypes-type.

    DATA :et_connections TYPE ztthr_utility_get_attachment,
          es_stream      TYPE ty_s_media_resource,
          e_filename     TYPE filename_al11.

    DATA:lv_mimetype  TYPE mimetypes-type,
         lv_mimetype1 TYPE mimetypes-type,
         lv_filename  TYPE string.

    DATA: ls_meta   TYPE sfpmetadata,
          lx_fpex   TYPE REF TO cx_fp_runtime,
          lo_fp     TYPE REF TO if_fp,
          lo_pdfobj TYPE REF TO if_fp_pdf_object.

    DATA: lv_form TYPE xstring.
    CONSTANTS: "lc_archivid    TYPE toaar-archiv_id VALUE 'ZC' commented by shubhamb on 12.09.2025 for Content Rep. ID changes
      lc_doc_type    TYPE toaom-ar_object VALUE 'ZDT_TA'.


    DATA(lt_connections) = VALUE connection_tab( ).
    DATA(lt_attributes)  = VALUE tt_toaat( ).
    DATA: lc_archivid    TYPE toaar-archiv_id.    "added by shubhamb on 12.09.2025 for Content Rep. ID changes
*     CONSTANTS lc_object_type TYPE toaom-sap_object VALUE 'ZBO_TA'.

    DATA: lc_object_type TYPE toaom-sap_object.

    IF iv_entity_name = 'AttachmentTReq'.
      lc_object_type = 'ZBO_TA'.
    ELSEIF iv_entity_name = 'Attachment'.
      lc_object_type = 'ZBO_TA'.
    ELSE.
      lc_object_type = 'ZBO_TA_V'.
    ENDIF.


    CALL FUNCTION 'ARCHIV_GET_CONNECTIONS'
      EXPORTING
        objecttype      = lc_object_type
*       object_id       = ''
        documenttype    = lc_doc_type
        archiv_id       = 'ZC'
        arc_doc_id      = CONV toav0-arc_doc_id( lv_docid )
*       from_ar_date    = ''
*       until_ar_date   = ''
      TABLES
        connections     = lt_connections
        file_attributes = lt_attributes
      EXCEPTIONS
        nothing_found   = 1
        OTHERS          = 2.
    IF sy-subrc = 0 AND lt_connections IS NOT INITIAL.
      SELECT ar_object,
             objecttext
        FROM toasp INTO TABLE @DATA(lt_object_name) FOR ALL ENTRIES IN @lt_connections
                              WHERE ar_object = @lt_connections-ar_object
                                AND language  = @sy-langu.
      IF lt_connections[] IS NOT INITIAL.
        LOOP AT lt_connections ASSIGNING FIELD-SYMBOL(<ls_connections>).
          DATA(lt_binary_1024) = VALUE rmps_t_1024( ).
          DATA(lv_doc_type) = CONV toadd-doc_type( <ls_connections>-ar_object ).
          CALL FUNCTION 'ARCHIVOBJECT_GET_TABLE'
            EXPORTING
              archiv_id                = <ls_connections>-archiv_id
              document_type            = lv_doc_type
              archiv_doc_id            = <ls_connections>-arc_doc_id
              all_components           = abap_true
              signature                = abap_true
            TABLES
              binarchivobject          = lt_binary_1024
            EXCEPTIONS
              error_archiv             = 1
              error_communicationtable = 2
              error_kernel             = 3
              OTHERS                   = 4.
          IF sy-subrc = 0.
            DATA(lt_binary_data) = cl_rmps_general_functions=>convert_1024_to_255( lt_binary_1024[] ).
          ENDIF.
          TRY.
              DATA(ls_attributes) = VALUE #( lt_attributes[ arc_doc_id = <ls_connections>-arc_doc_id ] OPTIONAL ).
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          CALL FUNCTION 'SDOK_MIMETYPE_GET'
            EXPORTING
              extension = <ls_connections>-reserve
            IMPORTING
              mimetype  = rv_mime_type.
          IF rv_mime_type EQ 'application/octet-stream'.      " At backend the mimetype stored is not supported.
            rv_mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'.
          ELSEIF rv_mime_type EQ 'application/vnd.ms-excel'.
            rv_mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64'.
          ENDIF.


          et_connections = VALUE #( BASE et_connections ( VALUE #( BASE CORRESPONDING #( <ls_connections> )
                                                  filename    = ls_attributes-filename
                                                  creator     = ls_attributes-creator
                                                  descr       = ls_attributes-descr
                                                  creatime    = ls_attributes-creatime
                                                  mimetype    =  rv_mime_type
                                                  doc_xstring = cl_bcs_convert=>solix_to_xstring( lt_binary_data )
                                                  binary_data = lt_binary_data
                                                  object_name = VALUE #( lt_object_name[ ar_object = <ls_connections>-ar_object ] OPTIONAL ) ) ) ).
        ENDLOOP.
        READ TABLE et_connections INTO DATA(ls_connections) INDEX 1.
        IF sy-subrc = 0.
          lv_form = ls_connections-doc_xstring.
          es_stream-mime_type = ls_connections-mimetype.
          lv_mimetype = ls_connections-mimetype.
          lv_mimetype = ls_connections-reserve.
          "Set the pdf header
          TRY.
              "Create PDF Object.
              lo_fp = cl_fp=>get_reference( ).
              lo_pdfobj = lo_fp->create_pdf_object( connection = 'ADS' ).
              lo_pdfobj->set_document( pdfdata = lv_form ).
              "Set title.
              ls_meta-title = 'TA'.
              lo_pdfobj->set_metadata( metadata = ls_meta ).
              lo_pdfobj->execute( ).
              "Get the PDF content back with title
              lo_pdfobj->get_document( IMPORTING pdfdata = lv_form ).
            CATCH cx_fp_runtime_internal
                  cx_fp_runtime_system
                  cx_fp_runtime_usage INTO lx_fpex.
              DATA(lv_message) = lx_fpex->get_text( ).
          ENDTRY.
          es_stream-mime_type = ls_connections-mimetype.
          es_stream-value = ls_connections-doc_xstring.
          e_filename = ls_connections-filename.
        ENDIF.

        " Set content disposition header for download
        set_header( is_header = VALUE #(
          name  = 'Content-Disposition'
          value = |attachment; filename="{ e_filename }"|
        ) ).


        copy_data_to_ref(
          EXPORTING
            is_data = es_stream
          CHANGING
            cr_data = er_stream ).
      ENDIF.
    ELSE.
      " Use this for class-based exception:
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception
        EXPORTING
          textid = /iwbep/cx_mgw_tech_exception=>internal_error.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->ATTACHMENTSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_ATTACHMENT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method ATTACHMENTSET_GET_ENTITYSET.
    DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'REQNO' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_reqType) = VALUE #( it_filter_select_options[ property = 'REQTYPE' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA: lv_name TYPE emnam.
    DATA: lt_entityset TYPE zcl_zwm_temp_adv_mpc=>tt_attachmenttreq.

    SELECT
      FROM ztwm_temp_attach
      FIELDS
        REQNO,
        DOC_ID,
        FILE_NAME,
        UPDATED_BY,
        UPDATED_ON
      WHERE reqno = @lv_req
      AND reqtype = @lv_reqType
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

    IF sy-subrc = 0.
      LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_entity>).
        DATA(lv_CurrPernr) = <lfs_entity>-updated_by.
        CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
          EXPORTING
            person_no    = CONV pernr_d( lv_CurrPernr )
          IMPORTING
            name_with_no = lv_name.

        <lfs_entity>-updated_by  = lv_name.
      ENDLOOP.
    ENDIF.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->ATTACHMENTTREQSE_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_ATTACHMENTTREQ
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD attachmenttreqse_get_entityset.
    DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'REQNO' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA: lv_name TYPE emnam.
    DATA: lt_entityset TYPE zcl_zwm_temp_adv_mpc=>tt_attachmenttreq.

    SELECT
      FROM ztwm_temp_attach
      FIELDS
          reqno,
          doc_id,
          reqtype
*          file_name,
*          updated_by
      WHERE reqno = @lv_req
      AND reqtype = 'T'
*      INTO TABLE @DATA(lt_attachment).
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.

*    MOVE-CORRESPONDING lt_attachment TO lt_entityset.
*
*    IF sy-subrc = 0.
*      LOOP AT lt_entityset ASSIGNING FIELD-SYMBOL(<lfs_entity>).
*        DATA(lv_CurrPernr) = <lfs_entity>-updated_by.
*        CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
*          EXPORTING
*            person_no    = CONV pernr_d( lv_CurrPernr )
*          IMPORTING
*            name_with_no = lv_name.
*
*        <lfs_entity>-updated_by  = lv_name.
*      ENDLOOP.
*      MOVE-CORRESPONDING lt_entityset TO et_entityset.
*    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->ATTACHMENTVREQSE_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_ATTACHMENTVREQ
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method ATTACHMENTVREQSE_GET_ENTITYSET.
**TRY.
*CALL METHOD SUPER->ATTACHMENTVREQSE_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_BANKLEDGERSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_BANKLEDGER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_bankledgerset_get_entityset.

    DATA: lv_pernr TYPE ess_emp-employeenumber.
    DATA: lt_entity  type  zcl_zwm_temp_adv_mpc=>tt_f4_bankledger.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    SELECT SINGLE
      FROM zthr_emp_master
      FIELDS profit_centre
      WHERE pernr = @lv_pernr
      INTO @DATA(lv_pc).

    SELECT
      FROM fagl_t8a30
      FIELDS
        konto_von
      WHERE bukrs = '1000'
       AND  ktopl = '1000'
       AND  prctr = @lv_pc
      INTO TABLE @DATA(lt_bankfrom).

    LOOP AT lt_bankfrom ASSIGNING FIELD-SYMBOL(<lfs_bankform>).
      <lfs_bankform>-konto_von = <lfs_bankform>-konto_von + 1.
    ENDLOOP.



  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->FIOVERVIEWSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_FIOVERVIEW
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD fioverviewset_get_entityset.

    DATA(lv_Action)      = VALUE #( it_filter_select_options[ property = 'Action' ]-select_options[ 1 ]-low OPTIONAL ).

    DATA: lv_pernr TYPE ess_emp-employeenumber.
    DATA : lt_status_val TYPE TABLE OF dd07v.
    DATA: lv_name        TYPE emnam,
          lv_PendingName TYPE emnam.
    DATA: lt_entityset TYPE zcl_zwm_temp_adv_mpc=>tt_overview,
          ls_entity    TYPE zcl_zwm_temp_adv_mpc=>ts_overview.
    "Domain values for FORM

    CALL FUNCTION 'GET_DOMAIN_VALUES'
      EXPORTING
        domname    = 'ZDOWM_STATUS'
        text       = 'X'
*       FILL_DD07L_TAB        = ' '
      TABLES
        values_tab = lt_status_val.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.


    SELECT  FROM ztmm_plant
     FIELDS
      zwh,
      zwhdesc
      WHERE zwhtype IN ( 'RO', 'CO' )
     INTO TABLE @DATA(lt_plant).
    IF sy-subrc = 0.

    ENDIF.

    SELECT  FROM ztwm_temp_activt
    FIELDS
     act_code,
     act_txt
    INTO TABLE @DATA(lt_activity).
    IF sy-subrc = 0.

    ENDIF.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
      EXPORTING
        person_no    = lv_pernr
      IMPORTING
        name_with_no = lv_name.


    SELECT SINGLE sub_area
      FROM zthr_emp_master
      WHERE pernr = @lv_pernr
      INTO @DATA(ls_area).

    IF lv_action = 'PP'.
      DATA(lv_status) = '20'.
    ELSEIF lv_action = 'PS'.
      lv_status = '25'.
    ENDIF.

    SELECT
      FROM ztwm_temp_master AS a
      INNER JOIN  ztwm_temp_detail AS b ON a~reqno = b~reqno
      FIELDS
      a~reqno,
      a~fyear,
      a~warehouse,
      a~req_amt,
      a~status,
      a~documentno_req,
      a~created_by,
      a~created_on,
      b~activity
      WHERE
        a~warehouse = @ls_area
        AND a~status = @lv_status
  INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    IF sy-subrc = 0.
      SORT et_entityset BY reqno DESCENDING.
      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING reqno.
    ENDIF.
**
**
**
    LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<lfs_details>).

      DATA(lv_CurrPernr) = <lfs_details>-created_by.

      CALL FUNCTION 'HR_TMW_GET_EMPLOYEE_NAME'
        EXPORTING
          person_no    = CONV pernr_d( lv_CurrPernr )
        IMPORTING
          name_with_no = lv_name.

      <lfs_details>-status          = VALUE #( lt_status_val[ domvalue_l = <lfs_details>-status ]-ddtext OPTIONAL ).
      <lfs_details>-warehouse       = VALUE #( lt_plant[ zwh = <lfs_details>-warehouse ]-zwhdesc OPTIONAL ).
      <lfs_details>-activity        = VALUE #( lt_activity[ act_code = <lfs_details>-activity ]-act_txt OPTIONAL ).
      <lfs_details>-created_by      = lv_name.
    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->SERVICERECEIVERS_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_SERVICERECEIVER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD servicereceivers_get_entityset.
    DATA: lv_pernr TYPE pernr_d.
    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    SELECT SINGLE profit_centre FROM zthr_emp_master INTO @DATA(lv_prctr) WHERE pernr = @lv_pernr.

    SELECT SINGLE khinr,prctr
    FROM cepc INTO @DATA(ls_khinr) WHERE kokrs = '1000'
    AND prctr eq @lv_prctr.

    SELECT SINGLE descript FROM setheadert INTO @DATA(lv_desc) WHERE setclass = '0106'
      AND subclass = '1000' AND setname = @ls_khinr-khinr.
    SELECT SINGLE branch FROM j_1bbranch INTO @DATA(lv_bup) WHERE gstin = @lv_desc.

      select single * from T001W into @data(ls_main) where werks = @lv_prctr+6(4).

        data: ls_entity like LINE OF et_entityset.
        ls_entity-address = ls_main-STRAS.
        ls_entity-gst = lv_desc.
        ls_entity-name = ls_main-name1.
        ls_entity-pin = ls_main-PSTLZ.

        select single * from t005u into @data(ls_state) where BLAND = @ls_main-regio and land1 = 'IN' AND spras = 'E'..
        ls_entity-state = ls_state-bezei.
        ls_entity-statecode = ls_state-bland.

        APPEND ls_entity TO et_entityset.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->DELETEVOUCHERSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_DELETEVOUCHER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method DELETEVOUCHERSET_GET_ENTITYSET.

DATA(req) = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).
DATA(vreq) = VALUE #( it_filter_select_options[ property = 'VoucherReq' ]-select_options[ 1 ]-low OPTIONAL ).

data: lv_req type ztwm_temp_vouch-reqno,
      lv_vreq type ztwm_temp_vouch-voucherreq.

lv_req = req.
lv_vreq = vreq.


delete FROM ztwm_temp_vouch where reqno = @lv_req and voucherreq = @lv_vreq.
commit WORK.

IF SY-subrc = 0.

  "BOC shubham on 30.04.2026

          SELECT * FROM ztwm_temp_vouch INTO TABLE @DATA(lt_final_vouch)
            WHERE reqno = @lv_req.


          SORT lt_final_vouch BY voucherreq ASCENDING.

          DATA: lv_rem_amnt TYPE dmbtr.

          LOOP AT lt_final_vouch ASSIGNING FIELD-SYMBOL(<lfs_vou>).
            IF sy-tabix = 1.
              <lfs_vou>-remain_amt = <lfs_vou>-appr_amt - <lfs_vou>-voucher_amt.
              lv_rem_amnt = <lfs_vou>-remain_amt.
            ELSE.
              <lfs_vou>-remain_amt = lv_rem_amnt - <lfs_vou>-voucher_amt.
              lv_rem_amnt = <lfs_vou>-remain_amt.
            ENDIF.

          ENDLOOP.

          MODIFY ztwm_temp_vouch FROM TABLE lt_final_vouch.
          COMMIT WORK.

          DATA(LT_VOUCH) = lt_final_vouch.

          SORT lt_vouch BY voucherreq DESCENDING.
          READ TABLE lt_vouch INTO DATA(LS_VOUCH) INDEX 1.
          DATA: LS_MAIN TYPE ztwm_temp_master.

          SELECT SINGLE * FROM ztwm_temp_master INTO @DATA(LS_TEMP_MASTER)
             WHERE reqno = @lv_req.

            ls_temp_master-rem_amt = ls_vouch-remain_amt.

            MODIFY ztwm_temp_master FROM ls_temp_master.
            COMMIT WORK.

          "EOC shubham on 30.04.2026
ENDIF.

  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_ASSETCLASSSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_ASSETCLASS
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method F4_ASSETCLASSSET_GET_ENTITYSET.
    select ANLKL as class ,TXK50 as desc from ankt
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset WHERE spras = 'EN'.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_ASSETSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_ASSET
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD f4_assetset_get_entityset.

    DATA(lv_class)      = VALUE #( it_filter_select_options[ property = 'Class' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA: lv_pernr        TYPE ess_emp-employeenumber.

    DATA: lv_anlkl TYPE anla-anlkl.
    lv_anlkl = lv_class.
    SELECT anln1 FROM anla INTO TABLE @DATA(lt_anla) WHERE anlkl = @lv_anlkl.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.
    SELECT SINGLE * FROM zthr_emp_master INTO @DATA(ls_master) WHERE pernr = @lv_pernr.

*    select single * from pa0001 into @data(ls_pa0001) where pernr = @lv_pernr.
    IF lt_anla IS NOT INITIAL.
      SELECT anln1 FROM anlz INTO  TABLE
        @data(lt_asset) FOR ALL ENTRIES IN @lt_anla WHERE anln1 = @lt_anla-anln1
            AND bukrs = '1000' AND prctr = @ls_master-profit_centre.

         SELECT anln1 as assetno,txt50 as desc FROM anla INTO CORRESPONDING FIELDS OF TABLE
        @et_entityset FOR ALL ENTRIES IN @lt_asset WHERE anln1 = @lt_asset-anln1
           .

    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_STATUSFILTERS_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_STATUSFILTER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method F4_STATUSFILTERS_GET_ENTITYSET.

    data: ls_entity type zcl_zwm_temp_adv_mpc=>ts_f4_statusfilter.
    DATA: lt_values TYPE TABLE OF dd07v,
      ls_value  TYPE dd07v.

CALL FUNCTION 'DD_DOMVALUES_GET'
  EXPORTING
    domname        = 'ZDOWM_STATUS'
    text           = 'X'
    langu          = sy-langu
  TABLES
    dd07v_tab      = lt_values
  EXCEPTIONS
    wrong_textflag = 1
    OTHERS         = 2.

LOOP AT lt_values INTO ls_value.
  ls_entity-key = ls_value-domvalue_l.
  ls_entity-value = ls_value-ddtext.

  APPEND ls_entity TO et_entityset.
  CLEAR: ls_entity.
ENDLOOP.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->F4_UNSPENTBANKLE_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_F4_UNSPENTBANKLEDGER
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method F4_UNSPENTBANKLE_GET_ENTITYSET.

    data: ls_entity type zcl_zwm_temp_adv_mpc=>ts_f4_unspentbankledger.

     DATA: lv_pernr TYPE ess_emp-employeenumber.

    CALL FUNCTION 'HR_GETEMPLOYEEDATA_FROMUSER'
      EXPORTING
        username                  = sy-uname
      IMPORTING
        employeenumber            = lv_pernr
      EXCEPTIONS
        user_not_found            = 1
        countrygrouping_not_found = 2
        infty_not_found           = 3
        OTHERS                    = 4.
    IF sy-subrc <> 0.
    ENDIF.

    SELECT SINGLE
      FROM zthr_emp_master
      FIELDS profit_centre
      WHERE pernr = @lv_pernr
      INTO @DATA(lv_pc).

    select * from ZTWM_BANK_GL INTO TABLE @data(lt_ledg) WHERE prctr eq @lv_pc.

      loop at lt_ledg INTO data(ls_ledg).
        ls_entity-ledger = ls_ledg-hkont.
        ls_entity-prctr = ls_ledg-prctr.

        SELECT SINGLE TXT50 FROM SKAT INTO @DATA(LV_TXT)
              WHERE saknr = @ls_ledg-hkont.
          ls_entity-ledgertxt = lv_txt.

          APPEND ls_entity TO et_entityset.
          CLEAR ls_entity.

      ENDLOOP.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->LOGREPORTSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_LOGREPORT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method LOGREPORTSET_GET_ENTITYSET.

    data: ls_entity type zcl_zwm_temp_adv_mpc=>ts_logreport.
    DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'ZdocNo' ]-select_options[ 1 ]-low OPTIONAL ).

    data: lv_doc type ztmm_wf_remarks-zdocno.
    lv_doc = lv_req.

    DATA: lv_decision_cmt TYPE string,
          lt_ret             TYPE TABLE OF tline.
  CLEAR lv_decision_cmt.
    data:    lv_tstmp TYPE timestamp.
  SELECT * from zfit_workfl_log INTO TABLE @data(lt_log) where belnr = @lv_doc.
    sort lt_log by creation_date ASCENDING creation_time ASCENDING.
    data: lv_sl type int2.

      select * from ztmm_wf_remarks INTO CORRESPONDING FIELDS OF TABLE @et_entityset
        where ZDOCNO = @lv_doc.

    loop at lt_log INTO data(ls_log).

      if sy-tabix = 1.
        CONTINUE.
       ENDIF.

  CALL FUNCTION 'ZWF_TASK_DECISION_READ'
    EXPORTING
      im_wiid   = ls_log-w_id
    IMPORTING
      e_comment = lv_decision_cmt
    TABLES
      return    = lt_ret.

   TRY.
      ls_entity-zremarks = lt_ret[ 1 ]-tdline.
    CATCH cx_sy_itab_line_not_found.
  ENDTRY.

    ls_entity-uname = ls_log-workflow_user.
    lv_sl = lv_sl + 1.
    ls_entity-zsrno = lv_sl.

CONVERT DATE ls_log-creation_date
        TIME ls_log-creation_time
        INTO TIME STAMP lv_tstmp
        TIME ZONE sy-zonlo.

    ls_entity-zdatetime = lv_tstmp.

    APPEND ls_entity to et_entityset.
    clear: ls_entity.

  ENDLOOP.



    sort et_entityset by zdatetime DESCENDING.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->REJECTREMARKSSET_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_REJECTREMARKS
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method REJECTREMARKSSET_GET_ENTITYSET.

    data: ls_entity type zcl_zwm_temp_adv_mpc=>ts_rejectremarks.

    DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_vreq) = VALUE #( it_filter_select_options[ property = 'VoucherNo' ]-select_options[ 1 ]-low OPTIONAL ).


    select * from ztwm_temp_log INTO TABLE @data(lt_log)
      where reqno = @lv_req and voucherreq = @lv_vreq and status in ( '36', '31', '35' ).

      sort lt_log by changed_on DESCENDING.

*      READ TABLE lt_log INTO data(ls_log) INDEX 1.
      loop at  lt_log INTO data(ls_log)." INDEX 1.

        ls_entity-remarks = ls_log-remarks.
        ls_entity-reqno = ls_log-reqno.
        ls_entity-voucherno = ls_log-voucherreq.
        ls_entity-uname = ls_log-changed_by.
        ls_entity-zdatetime = ls_log-changed_on.

        APPEND ls_entity to et_entityset.
        clear: ls_entity.

      ENDLOOP.
      sort et_entityset by zdatetime DESCENDING.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->TEMPADVANCEBOOKS_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_TEMPADVANCEBOOK
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD tempadvancebooks_get_entityset.

    DATA: ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_tempadvancebook.

    DATA(lv_date_low) = VALUE #( it_filter_select_options[ property = 'Date_Low' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_date_high) = VALUE #( it_filter_select_options[ property = 'Date_High' ]-select_options[ 1 ]-low OPTIONAL ).

    DATA: lt_s_date  TYPE RANGE OF datum,
          lt_ts_date TYPE RANGE OF timestamp,
          lt_s_wh    TYPE RANGE OF werks_d.

    DATA: s_date_low  TYPE sy-datum,
          s_date_high TYPE sy-datum.

    DATA: lv_ts_low  TYPE timestamp,
          lv_ts_high TYPE timestamp.

    s_date_high = lv_date_high.
    s_date_low = lv_date_low.

    CONVERT DATE s_date_high TIME '235959' INTO TIME STAMP lv_ts_high TIME ZONE sy-zonlo.
    CONVERT DATE s_date_low TIME '000000' INTO TIME STAMP lv_ts_low TIME ZONE sy-zonlo.

    IF lv_ts_low IS NOT INITIAL.
      IF lv_ts_high IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'BT' low = lv_ts_low high = lv_ts_high ) TO lt_ts_date.
      ELSE.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_ts_low ) TO lt_ts_date.
      ENDIF.
    ENDIF.

    IF lv_date_low IS NOT INITIAL.
      IF lv_date_high IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'BT' low = lv_date_low high = lv_date_high ) TO lt_s_date.
      else.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_date_low ) TO lt_s_date.
   endif.
    ENDIF.

    SELECT * FROM ztwm_temp_master INTO TABLE @DATA(lt_master) WHERE created_on IN @lt_ts_date.

    IF lt_master IS NOT INITIAL.

      SELECT * FROM ztwm_temp_vouch INTO TABLE @DATA(lt_vouch) FOR ALL ENTRIES IN @lt_master
               WHERE reqno = @lt_master-reqno AND voucher_date IN @lt_s_date.

      IF lt_vouch IS NOT INITIAL.

        SELECT * FROM ztwm_temp_ledger INTO TABLE @DATA(lt_ledg) FOR ALL ENTRIES IN @lt_vouch
          WHERE reqno = @lt_vouch-reqno AND voucherreqno = @lt_vouch-voucherreq.

      ENDIF.

    ENDIF.

    DATA: lv_num TYPE n LENGTH 4.
    DATA lv_yyyymmdd TYPE string.
    SORT lt_ledg BY reqno voucherreqno.
    DATA: lv_open  TYPE ztwm_temp_master-appr_amt,
          LV_CLOSE_TEMP TYPE ztwm_temp_master-appr_amt,
          lv_close TYPE ztwm_temp_master-appr_amt.

    LOOP AT lt_master INTO DATA(ls_master).

      lv_num = lv_num + 1.
      ls_entity-sl_no = lv_num.

      lv_yyyymmdd = ls_master-created_on.
      lv_yyyymmdd = lv_yyyymmdd(8).
      ls_entity-date = lv_yyyymmdd.
      ls_entity-req_no = ls_master-reqno.
      ls_entity-temp_amt = ls_master-appr_amt.
      ls_entity-close_bal = ls_master-appr_amt.
      CONDENSE ls_entity-close_bal.
      APPEND ls_entity TO et_entityset.
      CLEAR: ls_entity.


      lv_open = ls_master-appr_amt.
      LOOP AT lt_ledg INTO DATA(ls_ledg) WHERE reqno = ls_master-reqno.

        READ TABLE lt_vouch INTO DATA(ls_vouch) WITH KEY reqno = ls_ledg-reqno voucherreq = ls_ledg-voucherreqno.
        IF sy-subrc = 0.
          ls_entity-date = ls_vouch-voucher_date.
        ENDIF.
        lv_num = LV_NUM + 1.
        ls_entity-sl_no = lv_num.
        ls_entity-req_no = ls_ledg-reqno.
        ls_entity-vouch_req_no = ls_ledg-voucherreqno.
        ls_entity-open_bal = lv_open.
        CONDENSE ls_entity-open_bal.
        ls_entity-ledg_amt = ls_ledg-amount_gst.
        CONDENSE ls_entity-ledg_amt.
        ls_entity-ledger = ls_ledg-ledgercode.

        lv_close_temp = lv_open - ls_ledg-amount_gst.
        ls_entity-close_bal = lv_close_temp.
        CONDENSE ls_entity-close_bal.

        lv_open = lv_close_temp.

        APPEND ls_entity to et_entityset.
        clear: ls_entity.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->TEMPADVANCEREPOR_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_TEMPADVANCEREPORT
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD tempadvancerepor_get_entityset.

    DATA: ls_entity TYPE zcl_zwm_temp_adv_mpc=>ts_tempadvancereport.
    DATA(lv_wh)      = VALUE #( it_filter_select_options[ property = 'Wh_Name' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_req) = VALUE #( it_filter_select_options[ property = 'Req_No' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_date_low) = VALUE #( it_filter_select_options[ property = 'Date_Low' ]-select_options[ 1 ]-low OPTIONAL ).
    DATA(lv_date_high) = VALUE #( it_filter_select_options[ property = 'Date_High' ]-select_options[ 1 ]-low OPTIONAL ).

    DATA: lt_s_date TYPE RANGE OF datum,
          LT_S_WH TYPE RANGE OF werks_d.

    IF lv_date_low IS NOT INITIAL.
      IF lv_date_high IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'BT' low = lv_date_low high = lv_date_high ) TO lt_s_date.
      else.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_date_low ) TO lt_s_date.
      endif.
    ENDIF.

    IF LV_WH IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_WH ) TO lt_s_wh.
      ENDIF.


    SELECT * FROM ztwm_temp_master INTO TABLE @DATA(lt_master)
                                WHERE warehouse IN @lt_s_wh AND req_pay_date IN @lt_s_date.

    IF lt_master IS NOT INITIAL.

      SELECT act_code, act_txt
      FROM ztwm_temp_activt
      FOR ALL ENTRIES IN @lt_master WHERE act_code = @lt_master-activity
        INTO TABLE @DATA(lt_act).

      SELECT werks, name1 FROM t001w FOR ALL ENTRIES IN @lt_master
        WHERE werks = @lt_master-warehouse INTO TABLE @DATA(lt_wh).

      SELECT reqno,voucherreq,voucher_date,APPR_AMT, REMAIN_AMT,DOCUMENTNO_VOUCH,VOUCHER_AMT FROM ztwm_temp_vouch
        FOR ALL ENTRIES IN @lt_master WHERE reqno = @lt_master-reqno
        INTO TABLE @DATA(lt_vou).

        DATA(LT_VOU_TEMP) = lt_vou[].
        DELETE lt_vou_temp WHERE documentno_vouch IS INITIAL.

      SORT lt_vou BY reqno DESCENDING voucherreq DESCENDING voucher_date DESCENDING.
      DELETE ADJACENT DUPLICATES FROM lt_vou COMPARING reqno.

    ENDIF.

    DATA: lv_num TYPE n LENGTH 4.
    DATA: LV_SPENT TYPE ztwm_temp_master-appr_amt.
    LOOP AT lt_master INTO DATA(ls_master).
      lv_num = lv_num + 1.

      ls_entity-sl_no = lv_num.

      READ TABLE lt_act INTO DATA(ls_act) WITH KEY act_code = ls_master-activity.
      IF sy-subrc = 0.
        ls_entity-activity = ls_act-act_txt.
      ENDIF.
      ls_entity-req_no = ls_master-reqno.

      READ TABLE lt_wh INTO DATA(ls_wh) WITH KEY werks = ls_master-warehouse.
      IF sy-subrc = 0.
        ls_entity-wh_name = ls_wh-name1.
      ENDIF.

      ls_entity-appr_amt = ls_master-appr_amt.
      CONDENSE ls_entity-appr_amt.
      ls_entity-pymnt_date = ls_master-req_pay_date.

      READ TABLE lt_vou INTO DATA(ls_vou) WITH KEY reqno = ls_master-reqno.
      IF sy-subrc = 0.
        ls_entity-date_gen = ls_vou-voucher_date.

      ENDIF.

      LOOP AT lt_vou_temp INTO DATA(LS_TEMP) WHERE reqno = ls_master-reqno.

        lv_spent = lv_spent + ls_temp-voucher_amt.

        ENDLOOP.


      ls_entity-dep_amt = ls_master-unspent_amt.
      CONDENSE ls_entity-dep_amt.
      ls_entity-pend_bal = ls_master-appr_amt - ( lv_spent + ls_master-unspent_amt ).
      CONDENSE ls_entity-pend_bal.

      ls_entity-spent_amt = lv_spent.
      CONDENSE ls_entity-spent_amt.

      APPEND ls_entity TO et_entityset.
      CLEAR: ls_entity.

    ENDLOOP.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->UNSPENTDISPLAYSE_GET_ENTITY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IO_REQUEST_OBJECT              TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY(optional)
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [<---] ER_ENTITY                      TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TS_UNSPENTDISPLAY
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_ENTITY_CNTXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method UNSPENTDISPLAYSE_GET_ENTITY.

*      DATA(lv_req)  = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).
       DATA(lv_req) = VALUE #( it_key_tab[ name = 'ReqNo' ]-value OPTIONAL ).
    select SINGLE * from ztwm_temp_unsent INTO CORRESPONDING FIELDS OF
      @er_entity where reqno = @lv_req.

      select single remarks from ztwm_temp_log into @data(lv_remark) where reqno = @lv_req.

        er_entity-remark = lv_remark.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Protected Method ZCL_ZWM_TEMP_ADV_DPC_EXT->UNSPENTDISPLAYSE_GET_ENTITYSET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ENTITY_NAME                 TYPE        STRING
* | [--->] IV_ENTITY_SET_NAME             TYPE        STRING
* | [--->] IV_SOURCE_NAME                 TYPE        STRING
* | [--->] IT_FILTER_SELECT_OPTIONS       TYPE        /IWBEP/T_MGW_SELECT_OPTION
* | [--->] IS_PAGING                      TYPE        /IWBEP/S_MGW_PAGING
* | [--->] IT_KEY_TAB                     TYPE        /IWBEP/T_MGW_NAME_VALUE_PAIR
* | [--->] IT_NAVIGATION_PATH             TYPE        /IWBEP/T_MGW_NAVIGATION_PATH
* | [--->] IT_ORDER                       TYPE        /IWBEP/T_MGW_SORTING_ORDER
* | [--->] IV_FILTER_STRING               TYPE        STRING
* | [--->] IV_SEARCH_STRING               TYPE        STRING
* | [--->] IO_TECH_REQUEST_CONTEXT        TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITYSET(optional)
* | [<---] ET_ENTITYSET                   TYPE        ZCL_ZWM_TEMP_ADV_MPC=>TT_UNSPENTDISPLAY
* | [<---] ES_RESPONSE_CONTEXT            TYPE        /IWBEP/IF_MGW_APPL_SRV_RUNTIME=>TY_S_MGW_RESPONSE_CONTEXT
* | [!CX!] /IWBEP/CX_MGW_BUSI_EXCEPTION
* | [!CX!] /IWBEP/CX_MGW_TECH_EXCEPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD unspentdisplayse_get_entityset.

    DATA(lv_req)      = VALUE #( it_filter_select_options[ property = 'ReqNo' ]-select_options[ 1 ]-low OPTIONAL ).

    select * from ztwm_temp_unsent INTO CORRESPONDING FIELDS OF TABLE
      @et_entityset where reqno = @lv_req.
  ENDMETHOD.
ENDCLASS.


--------------------------------------------------------------------------------------------------------------------------------
