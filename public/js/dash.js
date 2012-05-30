var abacus = { hash: {} };

// convert list of (a, b, c) tuples to grid
// a->columns, b->rows, c->count
function tuplesToGrid(d, width, row, col, cell, reduce) {
    var rows = {}, cols = {}, cells = {};
    for(var i=0; i < d.length; ++i) {
	var r = row(d[i]);
	var c = col(d[i]);
	if(r != undefined && c != undefined) {
	    rows[r] = 1;
	    cols[c] = 1;
	    var nv = cell(d[i]);
	    if(nv != undefined) {
		if(c in cells == false) {
		    cells[c] = {};
		}
		if(cells[c][r] != undefined) {
		    cells[c][r].push(nv);
		} else {
		    cells[c][r] = [ nv ];
		}
	    }
	}
    }
    var sortedrow = [], sortedcol = [];
    for(var i in rows) if(rows.hasOwnProperty(i)) {
	sortedrow.push(i);
    }
    sortedrow.sort();
    for(var i in cols) if(cols.hasOwnProperty(i)) {
	sortedcol.push(i);
    }
    sortedcol.sort();
    var ret = [];
    for(var i=0; i<sortedrow.length; ++i) {
	var r = [ sortedrow[i] ];
	for(var j=0; j<width; ++j) {
	    var tr = cells[sortedcol[j]];
	    var c;
	    if(tr == undefined) {
		c = [];
	    } else {
		c = tr[sortedrow[i]];
		if(c == undefined) {
		    c = [];
		}
	    }
	    r.push(reduce(c));
	}
	ret.push(r);
    }
    return ret;
}

// paste (a, b, c, ...) into a grid, keyed on a. d is a 2d array of input data
function tuplesToColumns(stripe, d, columns)
{
    for(var i=0; i < d.length; ++i) {
	var k = d[i][columns[0]];
	if(k in stripe == false) {
	    stripe[k] = [];
	}
	for(var j=1; j<d[i].length; ++j) {
	    if(columns[j] != undefined) {
		stripe[k][columns[j]-1] = d[i][j];
	    }
	}
    }
    return stripe;
}

function columnsToGrid(d, defaults) {
    var roworder = [];
    for(var i in d) if(d.hasOwnProperty(i)) {
	roworder.push(i);
    }
    roworder.sort();
    var ret = [];
    for(var i=0; i<roworder.length; ++i) {
	var row = d[roworder[i]];
	row.unshift(roworder[i]);
	for(var j=0; j<defaults.length; ++j) {
	    if(row[j] == undefined) {
		row[j] = defaults[j];
	    }
	}
	ret.push(row);
    }
    return ret;
}

function showErrors(d) {
    if('errors' in d) {
	$.each(d.errors, function(index, value) {
	    $('<div class="alert alert-error"><a class="close" data-dismiss="alert">&times</a></div>').append($('<span/>', { text: value })).appendTo('#errors');
	});
    }
}

function rowChart(data, width) {
    var sl = tuplesToGrid(data, width+1, function(d) {
	return d[1];
    }, function(d) {
	return d[2];
    }, function(d) {
	return parseInt(d[0]);
    }, function(r) {
        var sum=0;
        for(var i=0; i<r.length; sum+=r[i++]);
        return sum;
    });
    var ret = [];
    for(var i=0; i<sl.length; ++i) {
	var values = sl[i];
	values.shift();
	ret.push(values);
    }
    return ret;
}

function sparkline(data, width, prefix, parameters) {
    var sl = rowChart(data, width);
    for(var i=0; i<sl.length; ++i) {
	$(prefix + i).sparkline(sl[i], parameters);
    }
}

function addStatic(base, sql) {
    $('#staticcsv').attr('href', base + "sql=" + encodeURIComponent(sql));
}

function addTools() {
    var oTable = $('#maintable').dataTable();
    var oTableTools = new TableTools( oTable, {
	"buttons": [ "copy", "csv", "xls", "pdf", "print" ]
    });
    $('#tabletools').replaceWith(oTableTools.dom.container);
}

function slug(s) {
    s = s.replace(/\s+/g, '-');
    s = s.replace(/[^a-zA-Z0-9-]/g, '');
    return s.substr(0, 30).toLowerCase();
}

function simpleTable(dom, url, base, sql) {
    dom.attr({ 
	cellpadding: 0,
	cellspacing: 0,
	border: 0,
	'class': 'table table-striped table-bordered'
    });
    dom.append('<thead><tr></tr></thead><tbody></tbody>');
    $.ajax({
	url: url,
	dataType: 'json',
	data: {
	    sql: sql
	},
	success: function(data) {
	    showErrors(data);
	    var cols = [];
	    for(var i=0; i < data.columns.length; ++i) {
		cols.push({ sTitle: data.columns[i] });
	    }
	    dom.dataTable({
		aaData: data.data,
		aoColumns: cols,
		bPaginate: false,
		bDestroy: true,
		oTableTools: {
		    "sSwfPath": base + "/swf/copy_cvs_xls_pdf.swf"
		},
		sDom: "<'row'f>t<'row'<'span6'T><'span6'>>"
	    }).fnAdjustColumnSizing();
	},
	error: function(jqxhr, testStatus, errorThrown) {
	    $('<div class="alert alert-error"><a class="close" data-dismiss="alert">&times</a></div>').append($('<span/>', { text: 'Failed to run SQL query: ' +errorThrown })).appendTo('#errors');
	}
    });
}

function pagedTable(dom, url, base, sql) {
    dom.attr({ 
	cellpadding: 0,
	cellspacing: 0,
	border: 0,
	'class': 'table table-striped table-bordered'
    });
    dom.append('<thead><tr></tr></thead><tbody></tbody>');
    $.ajax({
	url: url,
	dataType: 'json',
	data: {
	    sql: sql
	},
	success: function(data) {
	    showErrors(data);
	    var cols = [];
	    for(var i=0; i < data.columns.length; ++i) {
		cols.push({ sTitle: data.columns[i] });
	    }
	    dom.dataTable({
		aaData: data.data,
		aoColumns: cols,
		bPaginate: true,
		bDestroy: true,
		oTableTools: {
		    "sSwfPath": base + "/swf/copy_cvs_xls_pdf.swf"
		},
		sDom: "<'row'<'span6'l><'span6'f>r>t<'row'<'span6'i><'span6'p>><'row'<'span6'T><'span6'>>",
		sPaginationType: "bootstrap",
		oLanguage: {
		    sLengthMenu: "_MENU_ records per page"
		},
	    }).fnAdjustColumnSizing();
	},
	error: function(jqxhr, testStatus, errorThrown) {
	    $('<div class="alert alert-error"><a class="close" data-dismiss="alert">&times</a></div>').append($('<span/>', { text: 'Failed to run SQL query: ' +errorThrown })).appendTo('#errors');
	}
    });
}

jQuery.fn.dataTableExt.aTypes.unshift(
    function ( sData )
    {
	return (''+sData).match(/^[0-9,]+ ?([kmg]?b|bytes)$/i) ? 'file-size' : null;
    }
);

function parseSize(s) {
    var m = (''+s).match(/([0-9,]+) ?([kmg]b|bytes)$/i);
    if(m) {
	var i = parseInt(m[1].replace(/,/,''));
	var unit = m[2].toLowerCase();
	var mult = (unit=="gb") ? 1000000000 : (unit=="mb") ? 1000000 : (unit=="kb") ? 1000 : 1;
	return i * mult;
    }
    return 0;
}

jQuery.fn.dataTableExt.oSort['file-size-asc']  = function(a,b) {
    var x = parseSize(a);
    var y = parseSize(b);
     
    return ((x < y) ? -1 : ((x > y) ?  1 : 0));
};
 
jQuery.fn.dataTableExt.oSort['file-size-desc'] = function(a,b) {
    var x = parseSize(a);
    var y = parseSize(b);
 
    return ((x < y) ?  1 : ((x > y) ? -1 : 0));
};
