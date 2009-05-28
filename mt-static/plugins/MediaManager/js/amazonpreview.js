var preview_on = 1;
function updateAmazonPreview(asin) {
  var drop = getByID("img_drop").value;
  var drop_opt = '';
  if (drop == 'Left') {
    drop_opt = "_PB"; 
  } else if (drop == 'Right') {
    drop_opt = "_PC"; 
  }
  var rotation = '_PU' + parseInt(getByID("img_rot").value);
  var rot_opt = '';
  if (rotation != '_PU0') {
    rot_opt = rotation;
  }

  var blur = getByID("blur").value;
  var blur_opt = "";
  if (blur != "0") {
    blur_opt = '_BL' + blur;
  }

  var bull_opt = '';
  var bullet = getByID("bullet").value;
  if (bullet != '') {
    var percent = getByID("percent").value;
    if (percent == "") { percent = "10"; }
    bull_opt = "_" + bullet + percent;
  }

  var disk = getByID("disk").checked;
  var disk_opt = '';
  if (disk != '') {
    disk_opt = "_PF";
  }

  var size_opt = '_SCLZZZZZZZ';
  var size = getByID("img_size").value;
  if (size != "") {
    size_opt = size;
  }

  var options = size_opt + disk_opt + blur_opt + bull_opt + drop_opt + rot_opt + '_';
  var url = 'http://images.amazon.com/images/P/'+asin+'.01.'+options+'.jpg';
  var img = getByID("amazon-img");
  getByID("img-options-preview").style.backgroundImage = 'url(' + url + ')';
  if (!preview_on) return;
  var field = getByID("img-url");
  field.value = url;
}

function rotate( degrees, asin ) {
  var r = getByID("img_rot").value;
  r = parseInt(r) + degrees;
  if (r < -359 || r > 359) {
    r = 0;
  }
  var obj = getByID("img_rot");
  obj.value = r;
  updateAmazonPreview(asin);
}

function togglePreview(asin) {
  preview_on = getByID("preview_toggle").checked;
  var obj = getByID("img-options-preview"); 
  if (preview_on) {
    obj.style.visibility = "visible";
    updateAmazonPreview(asin);
  } else {
    obj.style.visibility = "hidden";    
  }
}
