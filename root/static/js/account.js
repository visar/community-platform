$(document).ready(function(){
  if (userHasLanguages) {
    $('#btnAddNewLanguage').show();
    $('#formAddUserLanguage').hide();
  }
});

function showFormAddUserLanguage() {
    $('#formAddUserLanguage').fadeIn();
    $('#btnAddNewLanguage').fadeOut();
}

function validateFormAddUserLanguage() {
    if ($.inArray($('#language_id'), userLanguages)) {
      return false;
    }
    return true;
}