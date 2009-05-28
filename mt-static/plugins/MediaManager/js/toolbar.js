function getByID(n) {
    var d = window.document;
    if (d.getElementById)
        return d.getElementById(n);
    else if (d.all)
        return d.all[n];
}

function updateAmazonPreview() {
  var asin;
  if (getByID("asin").value != '') {
    asin = getByID("asin").value;
  }

  var size_opt = '_SCLZZZZZZZ_';
  var size = getByID("img_size");
  if (size && size.value != "") {
    size_opt += 'SX' + size.value;
  }

  var drop = getByID("img_drop").value;
  var drop_opt = '';
  if (drop == 'left') {
    drop_opt = "_PB";
  } else if (drop == 'right') {
    drop_opt = "_PC";
  }

  var rotation = getByID("img_rot");
  var rot_opt = '';
  if (rotation && rotation.value != '' && rotation.value != 0) {
    rot_opt = '_PU' + rotation.value;
  }

  var blur = getByID("img_blur");
  var blur_opt = "";
  if (blur && blur.value != "0") {
    blur_opt = '_BL' + blur.value;
  }

  var options = blur_opt + drop_opt + size_opt + rot_opt + '_';
  var url = 'http://images.amazon.com/images/P/'+asin+'.01.'+options+'.jpg';
  var img = getByID("amazon-img");
  getByID("image-preview").style.backgroundImage = 'url(' + url + ')';
  getByID("img_url").value = url;
}

function updateLayoutPreview() {
  var layout = getByID("layout").value;
  var url = StaticURI + '/plugins/MediaManager/images/toolbar/layout-'+layout+'.png';
  getByID("layout-preview").src = url;
}

function setRating( r ) {
    for (i = 1; i <= 5; i++) {
      var star = getByID('star-' + i);
      if (i <= r) {
        star.src = StaticURI + "/plugins/MediaManager/images/toolbar/starbw-on.gif";
      } else {
        star.src = StaticURI + "/plugins/MediaManager/images/toolbar/starbw-off.gif";
      }
    }
    getByID("rating").value = r;
}

function rotate( degrees, asin ) {
  var obj = getByID("img_rot");
  var r = obj.value;
  if (r == 'NaN') { r = 0; }
  r = parseInt(r) + degrees;
  if (r < -359 || r > 359) {
    r = 0;
  }
  obj.value = r;
  updateAmazonPreview(asin);
}

function imgblur( degrees, asin) {
  var obj = getByID("img_blur");
  var r = obj.value;
  r = parseInt(r) + degrees;
  if (r < 0 || r > 100) {
    return;
  }
  obj.value = r;
  updateAmazonPreview(asin);
}

