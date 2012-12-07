<cfcomponent output="false">

  <cffunction name="init" access="public" output="false">
    <cfscript>
      this.version = "1.1.8"; 

      // add in our new accepted format
      application.wheels.formats.yaml = "text/yaml";
    </cfscript>
    <cfreturn this />
  </cffunction>

  <cffunction name="toYaml" access="public" output="false" returntype="string">
    <cfargument name="object" type="any" required="true" />
    <cfset var yaml = $createYamlObject() />
    <cfreturn yaml.dump(arguments.object) />
  </cffunction>

  <cffunction name="loadYaml" access="public" output="false" returntype="any">
    <cfargument name="string" type="string" required="true" />
    <cfset var yaml = $createYamlObject() />
    <cfreturn yaml.load(arguments.string) />
  </cffunction>

  <cffunction name="renderWith" access="public" returntype="any" output="false" mixin="controller">
    <cfargument name="data" required="true" type="any" />
    <cfargument name="controller" type="string" required="false" default="#variables.params.controller#" />
    <cfargument name="action" type="string" required="false" default="#variables.params.action#" />
    <cfargument name="template" type="string" required="false" default="" />
    <cfargument name="layout" type="any" required="false" />
    <cfargument name="cache" type="any" required="false" default="" />
    <cfargument name="returnAs" type="string" required="false" default="" />
    <cfargument name="hideDebugInformation" type="boolean" required="false" default="false" />
    <cfscript>
      var loc = {};

      $args(name="renderWith", args=arguments);
      loc.contentType = $requestContentType();
      loc.acceptableFormats = $acceptableFormats(action=arguments.action);
      
      // default to html if the content type found is not acceptable
      if (not ListFindNoCase(loc.acceptableFormats, loc.contentType))
        loc.contentType = "html";
      
      // call render page and exit if we are just rendering html
      if (loc.contentType == "html")
      {
        StructDelete(arguments, "data", false); 
        return renderPage(argumentCollection=arguments);
      }
      
      loc.templateName = $generateRenderWithTemplatePath(argumentCollection=arguments, contentType=loc.contentType);
      loc.templatePathExists = $formatTemplatePathExists($name=loc.templateName); 
      
      if (loc.templatePathExists)
        loc.content = renderPage(argumentCollection=arguments, template=loc.templateName, returnAs="string", layout=false, hideDebugInformation=true);
      
      // throw an error if we rendered a pdf template and we got here, the cfdocument call should have stopped processing
      if (loc.contentType == "pdf" && application.wheels.showErrorInformation && loc.templatePathExists)
        $throw(type="Wheels.PdfRenderingError"
          , message="When rendering the a PDF file, don't specify the filename attribute. This will stream the PDF straight to the browser.");

      // throw an error if we do not have a template to render the content type that we do not have defaults for
      if (!ListFindNoCase("json,xml,yaml", loc.contentType) && !StructKeyExists(loc, "content") && application.wheels.showErrorInformation)
      {
        $throw(type="Wheels.renderingError"
          , message="To render the #loc.contentType# content type, create the template `#loc.templateName#.cfm` for the #arguments.controller# controller.");
      }
          
      // set our header based on our mime type
      $header(name="content-type", value=application.wheels.formats[loc.contentType], charset="utf-8");
      
      // if we do not have the loc.content variable and we are not rendering html then try to create it
      if (!StructKeyExists(loc, "content"))
      {
        switch (loc.contentType)
        {
          case "json": { loc.content = SerializeJSON(arguments.data); break; }
          case "yaml": { loc.content = toYaml(arguments.data); break; };
          case "xml": { loc.content = $toXml(arguments.data); break; };
        }
      }
      
      // if the developer passed in returnAs = string then return the generated content to them
      if (arguments.returnAs == "string")
        return loc.content;
        
      renderText(loc.content);
    </cfscript>
  </cffunction>  
  
  <cffunction name="$createYamlObject" access="public" output="false" returntype="string">
    <cfset var javaLoader = $createYamlJavaLoader() />
    <cfreturn javaLoader.create("org.yaml.snakeyaml.Yaml").init() />
  </cffunction>

  <cffunction name="$createYamlJavaLoader" access="public" output="false" returntype="any">
    <cfscript>
      var loc = {};
      
      if (!StructKeyExists(server, "javaloader") || !IsStruct(server.javaloader))
        server.javaloader = {};
      
      if (StructKeyExists(server.javaloader, "yaml"))
        return server.javaloader.yaml;
      
      loc.relativePluginPath = application.wheels.webPath & application.wheels.pluginPath & "/yaml/";
      loc.classPath = Replace(Replace(loc.relativePluginPath, "/", ".", "all") & "javaloader", ".", "", "one");
      
      loc.paths = ArrayNew(1);
      loc.paths[1] = ExpandPath(loc.relativePluginPath & "lib/snakeyaml-1.11.jar");
      
      // set the javaLoader to the request in case we use it again
      server.javaloader.yaml = $createObjectFromRoot(path=loc.classPath, fileName="JavaLoader", method="init", loadPaths=loc.paths, loadColdFusionClassPath=false);
    </cfscript>
    <cfreturn server.javaloader.yaml />
  </cffunction>
  
</cfcomponent>