import std.stdio;
import bindbc.glfw;
import bindbc.opengl;
import inochi2d;
import std.string;
import inochi2d.core.dbg;
import std.process;

extern(C) void windowResizeCallback(GLFWwindow* window, int width, int height) nothrow {
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

	// Create Window and initialize OpenGL 4.2 with compat profile
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_COMPAT_PROFILE);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);

	glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER, environment.get("TRANSPARENT") == "1" ? GLFW_TRUE : GLFW_FALSE);

	glfwWindowHint(GL_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE, 8);
	window = glfwCreateWindow(1024, 1024, "Inochi2D Viewer".toStringz, null, null);
	glfwMakeContextCurrent(window);
	glfwSetFramebufferSizeCallback(window, &windowResizeCallback);
	glfwSetScrollCallback(window, &scrollCallback);
	loadOpenGL();

	// Initialize Inochi2D
	inInit(cast(double function())glfwGetTime);

	// Prepare viewport
	int sceneWidth, sceneHeight;
	inSetViewport(1024, 1024);
	inGetViewport(sceneWidth, sceneHeight);

	inGetCamera().scale = vec2(1);

	Puppet[] puppets;

	float size = (args.length-1)*2048;
	float halfway = size/2;
	if (args.length == 1) {
		puppets ~= inLoadPuppet(args[1]);
	} else {
		foreach(i; 1..args.length) {
			puppets ~= inLoadPuppet(args[i]);

			puppets[i-1].root.localTransform.translation.x = (((i)*2048)-halfway)-1024;
		}
	}
	
	if (environment.get("DEBUG") == "1") {
		inDbgDrawMeshOutlines = true;
		inDbgDrawMeshVertexPoints = true;
		inDbgDrawMeshOrientation = true;
	}

	while(!glfwWindowShouldClose(window)) {
		glClear(GL_COLOR_BUFFER_BIT);

		// Update Inochi2D
		inUpdate();

		inBeginScene();

			updateCamera();

			foreach(puppet; puppets) {
				puppet.update();
				puppet.draw();
				puppet.drawOutlines();
			}

		inEndScene();

		// Draws the scene to the screen
		inDrawScene(vec4(0, 0, 2048, 2048));

		// End of loop stuff
		glfwSwapBuffers(window);
		glfwPollEvents();
	}
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