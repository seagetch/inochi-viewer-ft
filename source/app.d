import std.stdio;
import bindbc.glfw;
import bindbc.opengl;
import inochi2d;
import std.string;
import std.range;
import inochi2d.core.dbg;
import std.process;
import adaptor;

extern(C) void fbResizeCallback(GLFWwindow* window, int width, int height) nothrow {
	inSetViewport(width, height);
}

float scalev = 1;
extern(C) void scrollCallback(GLFWwindow* window, double xoffset, double yoffset) nothrow{
	auto camera = (cast(Camera function() nothrow)&inGetCamera)();

	scalev = camera.scale.x;
	camera.scale += vec2((yoffset*(0.05*scalev)));
	camera.scale = vec2(clamp(camera.scale.x, 0.01, 1));
}

GLFWwindow* window;
void main(string[] args)
{
	if (args.length == 1) {
		writeln("No model specified!");
		return;
	}

	// Loads GLFW
	loadGLFW();
	glfwInit();
	version(OSX) {
		pragma(msg, "Building in macOS support mode...");

		// macOS only supports up to GL 4.1 with some extra stuff
		glfwWindowHint (GLFW_CONTEXT_VERSION_MAJOR, 4);
		glfwWindowHint (GLFW_CONTEXT_VERSION_MINOR, 1);
		glfwWindowHint (GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
		glfwWindowHint (GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	} else {

		// Create Window and initialize OpenGL 4.2 with compat profile
		glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
		glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
		glfwWindowHint (GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
		glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_COMPAT_PROFILE);
	}

	glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER, environment.get("TRANSPARENT") == "1" ? GLFW_TRUE : GLFW_FALSE);

	glfwWindowHint(GL_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE, 8);
	window = glfwCreateWindow(1024, 1024, "Inochi2D Viewer".toStringz, null, null);
	glfwMakeContextCurrent(window);
	glfwSetFramebufferSizeCallback(window, &fbResizeCallback);
	glfwSetScrollCallback(window, &scrollCallback);
	loadOpenGL();

	// Initialize Inochi2D
	inInit(cast(double function())glfwGetTime);

	// Prepare viewport
	int sceneWidth, sceneHeight;
	glfwGetFramebufferSize(window, &sceneWidth, &sceneHeight);
	inSetViewport(sceneWidth, sceneHeight);

	inGetCamera().scale = vec2(1);

	Puppet[] puppets;

	float size = 2048;
	float halfway = size/2;

	args.popFront();

//	foreach(i; 1..args.length) {
		auto i = 1;
		puppets ~= inLoadPuppet(args[i-1]);
		puppets[i-1].root.localTransform.translation.x = (((i)*2048)-halfway)-1024;

		import std.array : join;

		auto meta = puppets[i-1].meta;
		writefln("---Model Info---\n%s by %s & %s\n%s\n", 
			meta.name, 
			meta.artist,
			meta.rigger,
			meta.copyright
		);
//	}

	args.popFront();
	writeln("args=", args);
	TrackingMode defaultMode = TrackingMode.None;
	while (args.length > 0) {
		auto mode = cast(TrackingMode)args[0];
		writeln("mode=", mode);
		args.popFront();
		string[string] options = ["appName": "inochi-viewer"];
		switch (mode) {
			case TrackingMode.VMC:
				break;

			case TrackingMode.VTS: // VTubeStudio
				auto address = "127.0.0.1";
				if (args.length > 0) {
					address = args[0];
					args.popFront();
				}
				options["phoneIP"] = address;
				invStartAdaptor(TrackingMode.VTS, options);
				if (defaultMode == TrackingMode.None) {
					defaultMode = mode;
					invSetDefaultMode(mode);
				}
				break;

			case TrackingMode.OSF: //  OpenSeeFace
				invStartAdaptor(TrackingMode.OSF, options);
				if (defaultMode == TrackingMode.None) {
					defaultMode = mode;
					invSetDefaultMode(mode);					
				}
				break;

			case TrackingMode.JML: //  JinsMemeLogger
				invStartAdaptor(TrackingMode.JML, options);
				if (defaultMode == TrackingMode.None) {
					defaultMode = mode;
					invSetDefaultMode(mode);
				}
				break;

			default:
				break;
		}
	}

	TrackingMode[string] modeMap = ["Eye L Blink": TrackingMode.VTS, "Eye R Blink": TrackingMode.VTS];
	invSetTrackingModeMap(modeMap);
	
	if (environment.get("DEBUG") == "1") {
		inDbgDrawMeshOutlines = true;
		inDbgDrawMeshVertexPoints = true;
		inDbgDrawMeshOrientation = true;
	}

	invSetPuppet(puppets[0]);
	invSetAutomator();        
	
	while(!glfwWindowShouldClose(window)) {
//		glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		// Update Inochi2D
		inUpdate();

		inBeginScene();

			updateCamera();
			invUpdate();
			foreach(puppet; puppets) {
				puppet.update();
				puppet.draw();
				//puppet.drawOutlines();
			}

		inEndScene();

		// Draws the scene to the screen
		int w, h;
		inGetViewport(w, h);
		inDrawScene(vec4(0, 0, w, h));

		// End of loop stuff
		glfwSwapBuffers(window);
		glfwPollEvents();
	}

	invStopAdaptors();
}

bool moving;
double sx = 0, sy = 0;
double csx = 0, csy = 0;
void updateCamera() {
	double x = 0, y = 0;
	int w, h;
	glfwGetCursorPos(window, &x, &y);
	glfwGetWindowSize(window, &w, &h);

	auto camera = inGetCamera();
	
	if (moving && !glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT)) moving = false;
	if (!moving && glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT)) {
		moving = true;
		sx = x;
		sy = y;
		csx = camera.position.x;
		csy = camera.position.y;
	}

	if (moving) {
		float ascalev = 0.5+clamp(1-scalev, 0.1, 1);

		camera.position = vec2(
			csx - (sx-x)*ascalev,
			csy - (sy-y)*ascalev
		);
	}
}