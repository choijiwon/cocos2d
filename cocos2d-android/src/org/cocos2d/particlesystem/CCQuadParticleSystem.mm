package org.cocos2d.particlesystem;

import java.nio.FloatBuffer;

import org.cocos2d.nodes.CCSpriteFrame;
import org.cocos2d.utils.BufferProvider;

/** CCQuadParticleSystem is a subclass of CCParticleSystem

 It includes all the features of ParticleSystem.

 Special features and Limitations:	
  - Particle size can be any float number.
  - The system can be scaled
  - The particles can be rotated
  - On 1st and 2nd gen iPhones: It is only a bit slower that CCPointParticleSystem
  - On 3rd gen iPhone and iPads: It is MUCH faster than CCPointParticleSystem
  - It consumes more RAM and more GPU memory than CCPointParticleSystem
  - It supports subrects
 @since v0.8
 */
public class CCQuadParticleSystem extends CCParticleSystem {
	// ccV2F_C4F_T2F_Quad	quads;		// quads to be rendered

	FloatBuffer         texCoords;
	FloatBuffer         vertices;
	FloatBuffer         colors;

	ShortBuffer			indices;	// indices
	int				quadsID;	// VBO id

	// overriding the init method
	public CCQuadParticleSystem(int numberOfParticles) {
		super(numberOfParticles);

		// allocating data space
		// quads = malloc( sizeof(quads[0]) * totalParticles );
		texCoords	= BufferProvider.createFloatBuffer(4 * 2 * totalParticles);
		vertices 	= BufferProvider.createFloatBuffer(4 * 2 * totalParticles);
		colors  	= BufferProvider.createFloatBuffer(4 * 4 * totalParticles);
		
		indices = malloc( sizeof(indices[0]) * totalParticles * 6 );

		if( !quads || !indices) {
			NSLog(@"cocos2d: Particle system: not enough memory");
			if( quads )
				free( quads );
			if(indices)
				free(indices);

			[self release];
			return nil;
		}

		// initialize only once the texCoords and the indices
		[self initTexCoordsWithRect:CGRectMake(0, 0, 1, 1)];
		[self initIndices];

		// create the VBO buffer
		glGenBuffers(1, &quadsID);

		// initial binding
		glBindBuffer(GL_ARRAY_BUFFER, quadsID);
		glBufferData(GL_ARRAY_BUFFER, sizeof(quads[0])*totalParticles, quads,GL_DYNAMIC_DRAW);	
		glBindBuffer(GL_ARRAY_BUFFER, 0);		
	}

	@Override
	public void finalize()
	{
		free(quads);
		free(indices);
		glDeleteBuffers(1, &quadsID);

		[super dealloc];
	}

	// initilizes the text coords
	// rect should be in Texture coordinates, not pixel coordinates
	public void initTexCoordsWithRect(CGRect rect) {
		float bottomLeftX = rect.origin.x;
		float bottomLeftY = rect.origin.y;

		float bottomRightX = bottomLeftX + rect.size.width;
		float bottomRightY = bottomLeftY;

		float topLeftX = bottomLeftX;
		float topLeftY = bottomLeftY + rect.size.height;

		float topRightX = bottomRightX;
		float topRightY = topLeftY;

		// Important. Texture in cocos2d are inverted, so the Y component should be inverted
		CC_SWAP( topRightY, bottomRightY);
		CC_SWAP( topLeftY, bottomLeftY );

		for(int i=0; i<totalParticles; i++) {
			// bottom-left vertex:
			quads[i].bl.texCoords.u = bottomLeftX;
			quads[i].bl.texCoords.v = bottomLeftY;
			// bottom-right vertex:
			quads[i].br.texCoords.u = bottomRightX;
			quads[i].br.texCoords.v = bottomRightY;
			// top-left vertex:
			quads[i].tl.texCoords.u = topLeftX;
			quads[i].tl.texCoords.v = topLeftY;
			// top-right vertex:
			quads[i].tr.texCoords.u = topRightX;
			quads[i].tr.texCoords.v = topRightY;
		}
	}



	/** Sets a new texture with a rect. The rect is in pixels.
		@since v0.99.4
	 */
	public void setTexture(CCTexture2D texture, CGRect rect)
	{
		// Only update the texture if is different from the current one
		if( [texture name] != [texture_ name] )
			[super setTexture:texture];

		// convert to Tex coords

		float wide = [texture pixelsWide];
		float high = [texture pixelsHigh];
		rect.origin.x = rect.origin.x / wide;
		rect.origin.y = rect.origin.y / high;
		rect.size.width = rect.size.width / wide;
		rect.size.height = rect.size.height / high;
		[self initTexCoordsWithRect:rect];
	}

	
	public void setTexture(CCTexture2D texture)
	{
		[self setTexture:texture withRect:CGRectMake(0,0, [texture pixelsWide], [texture pixelsHigh] )];
	}


	/** Sets a new CCSpriteFrame as particle.
		WARNING: this method is experimental. Use setTexture:withRect instead.
		@since v0.99.4
	 */
	public void setDisplayFrame(CCSpriteFrame spriteFrame)
	{

		NSAssert( CGPointEqualToPoint( spriteFrame.offset , CGPointZero ), @"QuadParticle only supports SpriteFrames with no offsets");

		// update texture before updating texture rect
		if ( spriteFrame.texture.name != texture_.name )
			[self setTexture: spriteFrame.texture];
	}




	// initialices the indices for the vertices
	public void initIndices() {
		for( int i=0;i< totalParticles;i++) {
			indices[i*6+0] = i*4+0;
			indices[i*6+1] = i*4+1;
			indices[i*6+2] = i*4+2;

			indices[i*6+5] = i*4+1;
			indices[i*6+4] = i*4+2;
			indices[i*6+3] = i*4+3;
		}
	}

	public void updateQuad(CCParticle p, CGPoint newPos)
	{
		// colors
		quads[particleIdx].bl.colors = p->color;
		quads[particleIdx].br.colors = p->color;
		quads[particleIdx].tl.colors = p->color;
		quads[particleIdx].tr.colors = p->color;

		// vertices
		float size_2 = p->size/2;
		if( p->rotation ) {
			float x1 = -size_2;
			float y1 = -size_2;

			float x2 = size_2;
			float y2 = size_2;
			float x = newPos.x;
			float y = newPos.y;

			float r = (float)-CC_DEGREES_TO_RADIANS(p->rotation);
			float cr = cosf(r);
			float sr = sinf(r);
			float ax = x1 * cr - y1 * sr + x;
			float ay = x1 * sr + y1 * cr + y;
			float bx = x2 * cr - y1 * sr + x;
			float by = x2 * sr + y1 * cr + y;
			float cx = x2 * cr - y2 * sr + x;
			float cy = x2 * sr + y2 * cr + y;
			float dx = x1 * cr - y2 * sr + x;
			float dy = x1 * sr + y2 * cr + y;

			// bottom-left
			quads[particleIdx].bl.vertices.x = ax;
			quads[particleIdx].bl.vertices.y = ay;

			// bottom-right vertex:
			quads[particleIdx].br.vertices.x = bx;
			quads[particleIdx].br.vertices.y = by;

			// top-left vertex:
			quads[particleIdx].tl.vertices.x = dx;
			quads[particleIdx].tl.vertices.y = dy;

			// top-right vertex:
			quads[particleIdx].tr.vertices.x = cx;
			quads[particleIdx].tr.vertices.y = cy;
		} else {
			// bottom-left vertex:
			quads[particleIdx].bl.vertices.x = newPos.x - size_2;
			quads[particleIdx].bl.vertices.y = newPos.y - size_2;

			// bottom-right vertex:
			quads[particleIdx].br.vertices.x = newPos.x + size_2;
			quads[particleIdx].br.vertices.y = newPos.y - size_2;

			// top-left vertex:
			quads[particleIdx].tl.vertices.x = newPos.x - size_2;
			quads[particleIdx].tl.vertices.y = newPos.y + size_2;

			// top-right vertex:
			quads[particleIdx].tr.vertices.x = newPos.x + size_2;
			quads[particleIdx].tr.vertices.y = newPos.y + size_2;
		}
	}

	public void postStep()
	{
		glBindBuffer(GL_ARRAY_BUFFER, quadsID);
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(quads[0])*particleCount, quads);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	// overriding draw method
	public void draw()
	{
		// Default GL states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
		// Needed states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
		// Unneeded states: -


		glBindTexture(GL_TEXTURE_2D, texture_.name);

		glBindBuffer(GL_ARRAY_BUFFER, quadsID);

		#define kPointSize sizeof(quads[0].bl)
		glVertexPointer(2,GL_FLOAT, kPointSize, 0);

		glColorPointer(4, GL_FLOAT, kPointSize, (GLvoid*) offsetof(ccV2F_C4F_T2F,colors) );

		glTexCoordPointer(2, GL_FLOAT, kPointSize, (GLvoid*) offsetof(ccV2F_C4F_T2F,texCoords) );


		BOOL newBlend = NO;
		if( blendFunc_.src != CC_BLEND_SRC || blendFunc_.dst != CC_BLEND_DST ) {
			newBlend = YES;
			glBlendFunc( blendFunc_.src, blendFunc_.dst );
		}

		if( particleIdx != particleCount ) {
			NSLog(@"pd:%d, pc:%d", particleIdx, particleCount);
		}
		glDrawElements(GL_TRIANGLES, particleIdx*6, GL_UNSIGNED_SHORT, indices);

		// restore blend state
		if( newBlend )
			glBlendFunc( CC_BLEND_SRC, CC_BLEND_DST );


		glBindBuffer(GL_ARRAY_BUFFER, 0);

		// restore GL default state
		// -
	}


}

