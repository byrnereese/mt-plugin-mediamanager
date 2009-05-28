/* Taken from: http://onlinetools.org/articles/unobtrusivejavascript/cssjsseparation.html */
function jscss(a,o,c1,c2)
{
  switch (a){
    case 'swap':
      o.className=!jscss('check',o,c1)?o.className.replace(c2,c1):o.className.replace(c1,c2);
    break;
    case 'add':
      if(!jscss('check',o,c1)){o.className+=o.className?' '+c1:c1;}
    break;
    case 'remove':
      var rep=o.className.match(' '+c1)?' '+c1:c1;
      o.className=o.className.replace(rep,'');
    break;
    case 'check':
      return new RegExp('\\b'+c1+'\\b').test(o.className)
    break;
  }
}

var selected = -1;
function unselect( id ) {
  selected = -1;
  var p = getByID("asset-" + id);
  jscss('swap',p,'selected','unselected');
}
function select( id ) {
  selected = id;
  getByID('selected').value = id;
  var p = getByID("asset-" + id);
  jscss('swap',p,'unselected','selected');
}
function toggle_select( id ) {
  if (selected != -1 && selected != id) {
    unselect(selected);
    select(id);
  } else if (selected == id) {
    unselect(id);
  } else {
    select(id);
  }
}

// toggle visibility
function do_confirm( string, url ) {
  var answer = confirm(string);
  if (answer) {
    window.location = url;
  } else { 
    return false;
  }
  return true;
}

function enableFilterButton() {
    getByID("filter-button").style.display = "inline";
}

function toggleFilter() {
    var filterActive = getByID("filter-active");
    if (filterActive.style.display == "none") {
        filterActive.style.display = "block";
        getByID("filter-select").style.display = "none";
    } else {
        filterActive.style.display = "none";
        getByID("filter-select").style.display = "block";
    }
}

function setFilterCol(choice) {
    getByID('filter-select').className = "filter-" + choice;
    var mode_obj = getByID('filter-mode');
    if (!mode_obj) { return; }
    if (choice == 'none')
        mode_obj.selectedIndex = 0;
    else {
        mode_obj.selectedIndex = 1;
        var fld = getByID('filter-col');
        if (choice == 'status')
            fld.selectedIndex = 0;
        else if (choice == 'category_id')
            fld.selectedIndex = 1;
        else if (choice == 'author_id')
            fld.selectedIndex = 2;
        col_span = getByID("filter-text-col");
        if (fld.selectedIndex > -1 && col_span)
            col_span.innerHTML = '<strong>' +
                fld.options[fld.selectedIndex].text + '</strong>';
    }
}

var tableSelect;
function init()
{
	// setup
	tableSelect = new TC.TableSelect( "selector" );
	tableSelect.rowSelect = true;
	setFilterCol('none');
}

TC.attachLoadEvent( init );

