CKEDITOR.editorConfig = function( config ) {
  config.toolbar= [ 
    ['Link','Unlink']
  ];
  config.removePlugins = 'language,image,forms,elementspath';
  config.height = 100;
  config.contentsCss = 'p { margin: 0px; padding: 0px; }';
};

