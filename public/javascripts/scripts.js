$(document).ready(function(){
  GUTTER_WIDTH = 20;
  COLUMN_WIDTH = 202;
  column_heights = init_columns();
  friend_positions = init_friend_positions(column_heights.length);
  resize_headers(column_heights.length);
  var async = is_async();
  var friends = $('.friend');
  NUM_FRIENDS = friends.length;
  processed_friends = 0;
  friends.each(function(index, elem) {
    process_friend($(elem), async);
  });
  bind_friend_images();
  bind_filter_buttons();
});

function bind_friend_images() {
  $('#friends').on('click', '.friend img', function() {
    var parent_div = $(this).parent();
    parent_div.fadeTo(200, 0.5);
    var friend_id = parent_div.data('friendId');
    var current_scale = parent_div.data('scale');
    var new_scale = (current_scale * 0.9).toFixed(3);
    parent_div.data('scale', new_scale);
    this.onload = function() {
      parent_div.fadeTo(200, 1);
      parent_div.data('imgWidth', this.width);
      parent_div.data('imgHeight', Math.round(200 / this.width * this.height)); // May get stretched
      var offset_string = parent_div.css('left');
      var offset = offset_string.substr(0, offset_string.length - 2);
      var column = Math.round(offset / (COLUMN_WIDTH + GUTTER_WIDTH));
      column_heights[column] = 0;
      var old_friend_positions_col = friend_positions[column];
      friend_positions[column] = [];
      $.each(old_friend_positions_col, function(index, elem_id) {
        set_box_position($('#friend_' + elem_id.toString()));
      });
    };
    this.src = '/image_proxy?scale=' + new_scale.toString() + '&friend_id=' + friend_id.toString();
  });
}

// Resizes headers to match width of columns
function resize_headers(num_cols) {
  var target_width = num_cols * (COLUMN_WIDTH + GUTTER_WIDTH) - GUTTER_WIDTH;
  $('#header').width(target_width);
  $('#filter_buttons').width(target_width);
}

// Processes one friend, starting with initial anchor to displaying the box
function process_friend(elem, async) {
  var friend_id = elem.data('friendId');
  var friend_name = elem.data('friendName');
  var scale = elem.data('scale');
  var on_complete_callback = (function(image, comp) {
    // console.log(comp.length.toString() + ' faces found for ' + friend_name);
    image.alt = friend_name;
    $(image).prependTo('#friend_' + friend_id);
    update_data_attrs(elem, image, comp);
    elem.addClass('num_faces_' + Math.min(comp.length, 3).toString());
    show_friend_box(elem);
    processed_friends += 1;
    update_processed_status();
    update_filter_buttons(comp.length);
  });
  var image = new Image();
  var src = '/image_proxy?scale=' + scale.toString() + '&friend_id=' + friend_id.toString();
  detect_faces(image, src, on_complete_callback, async);
}

function show_friend_box(box) {
  var num_faces = parseInt(box.data('numFaces'), 10);
  var active_filter = parseInt($('#filter_buttons a.active').data('numFaces'), 10);
  if (active_filter === -1 || active_filter === Math.min(num_faces, 3)) {
    set_box_position(box);
    box.show(); // Fading in is too slow here
  }
}

// Updates filter buttons with the correct counts
function update_filter_buttons(face_count) {
  var num_faces = Math.min(face_count, 3);
  var count_display = $("#face_count_filter_" + num_faces + " .image_count");
  var current_count = parseInt(count_display.html(), 10);
  count_display.html((current_count + 1).toString());
  var current_total = parseInt($('#face_count_filter .image_count').html(), 10);
  $('#face_count_filter .image_count').html((current_total + 1).toString());
}

// Binds clicks on filter buttons to hide/show the relevant photos
function bind_filter_buttons() {
  $('#filter_buttons').on('click', 'a', function() {
    column_heights = init_columns();
    var face_count = parseInt($(this).data('numFaces'), 10);    
    if (face_count !== -1) { // -1 is all photos
      $('.friend:not(.num_faces_' + face_count.toString() + ')').hide();
      $('.friend.num_faces_' + face_count.toString()).show().each(function(index, friend) {
        set_box_position($(friend));
      });
    } else {
      $('.friend').has('img').show().each(function(index, friend) {
        set_box_position($(friend));
      });
    }
    $('#filter_buttons a').removeClass('active');
    $(this).addClass('active');
  });
}

// Sets html5 data attributes for the friend box
function update_data_attrs(elem, image, comp) {
  elem.data('numFaces', comp.length);
  elem.data('imgWidth', image.width);
  elem.data('imgHeight', Math.round(200 / image.width * image.height)); // May get stretched
}

// Updates processed status displayed in header
function update_processed_status() {
  var processing_status;
  if (processed_friends === NUM_FRIENDS) {
    processing_status = '';
  } else {
    processing_status = '(processed ' + processed_friends.toString() +
                        ' of ' + NUM_FRIENDS.toString() + ' friends)';
  }
  $('#processing_status').html(processing_status);
}

// Sets position of the friend box to be at the bottom of the currently shortest column
// Updates column heights to include the new box
function set_box_position(friend_box) {
  var shortest_col = 0;
  for (var i = 1; i < column_heights.length; i++) {
    if (column_heights[i] < column_heights[shortest_col]) {
      shortest_col = i;
    }
  }
  var height = friend_box.data('imgHeight') + 15 + 4 + 2; // image + text + padding + borders
  var left_offset = (shortest_col * (COLUMN_WIDTH + GUTTER_WIDTH)) + GUTTER_WIDTH;
  var top_offset = column_heights[shortest_col];
  friend_box.css('left', left_offset.toString() + 'px');
  friend_box.css('top', top_offset.toString() + 'px');
  column_heights[shortest_col] += height + GUTTER_WIDTH;
  friend_positions[shortest_col].push(friend_box.data('friendId'));
}

// Calculates how many columns we can have and initializes the start heights to zero
function init_columns() {
  var container_width = $('#friends').width();
  var num_cols = Math.floor(container_width / (COLUMN_WIDTH + GUTTER_WIDTH));
  var column_heights = [];
  for (var i = 0; i < num_cols; i++) {
    column_heights[i] = 0;
  }
  return column_heights;
}

// Calculates how many columns we can have and initializes the start heights to zero
function init_friend_positions(len) {
  var friend_positions = [];
  for (var i = 0; i < len; i++) {
    friend_positions.push([]);
  }
  return friend_positions;
}

// Loads the image; when loaded, initializes face detection and callback
function detect_faces(image, src, append_func, async) {
  image.onload = function () {
      function post(comp) {
          append_func(image, comp);
      }
      if (async) {
          ccv.detect_objects({"canvas": ccv.grayscale(ccv.pre(image)),
                              "cascade": cascade,
                              "interval": 5,
                              "min_neighbors": 1,
                              "async": true,
                              "worker": 1})(post);
      } else {
          var comp = ccv.detect_objects({"canvas" : ccv.grayscale(ccv.pre(image)),
                                          "cascade" : cascade,
                                          "interval" : 5,
                                          "min_neighbors" : 1});
          post(comp);
      }
  };
  image.src = src;
}

// If mozilla, we can use background workers to process images async
function is_async() {
  var agent = (function( ua ) {
      ua = ua.toLowerCase();
      rwebkit = /(webkit)[ \/]([\w.]+)/;
      ropera = /(opera)(?:.*version)?[ \/]([\w.]+)/;
      rmsie = /(msie) ([\w.]+)/;
      rmozilla = /(mozilla)(?:.*? rv:([\w.]+))?/;
      var match = rwebkit.exec( ua ) ||
                  ropera.exec( ua ) ||
                  rmsie.exec( ua ) ||
                  ua.indexOf("compatible") < 0 && rmozilla.exec( ua ) ||
                  [];
      return { browser: match[1] || "", version: match[2] || "0" };
  })(navigator.userAgent);
  var async = (agent.browser == "mozilla");
  return async;
}
