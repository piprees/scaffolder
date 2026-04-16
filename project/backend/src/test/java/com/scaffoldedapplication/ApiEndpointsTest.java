package com.scaffoldedapplication;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApiEndpointsTest {
  @Autowired private MockMvc mockMvc;

  @Test
  void adminHealthEndpointIsAvailable() throws Exception {
    mockMvc
        .perform(get("/api/admin/health"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("UP"));
  }

  @Test
  @WithMockUser
  void userProfileEndpointIsAvailable() throws Exception {
    mockMvc
        .perform(get("/api/user/profile"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.username").value("demo-user"));
  }
}
