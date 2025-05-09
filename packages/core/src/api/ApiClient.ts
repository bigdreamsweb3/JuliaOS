// packages/core/src/api/ApiClient.ts

import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, AxiosError } from 'axios';

// Interface for our standardized error response from the Julia backend
export interface JuliaApiErrorDetail {
  message: string;
  error_code?: string;
  details?: any;
  status_code: number;
}

export interface JuliaApiResponseError {
  error: JuliaApiErrorDetail;
}

// Custom error class for API errors
export class ApiClientError extends Error {
  public readonly statusCode: number;
  public readonly errorCode?: string;
  public readonly errorDetails?: any;

  constructor(message: string, statusCode: number, errorCode?: string, errorDetails?: any) {
    super(message);
    this.name = 'ApiClientError';
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.errorDetails = errorDetails;
    Object.setPrototypeOf(this, ApiClientError.prototype);
  }
}

export class ApiClient {
  private axiosInstance: AxiosInstance;
  private apiKey: string;

  constructor(baseURL: string, apiKey: string) {
    this.apiKey = apiKey;
    this.axiosInstance = axios.create({
      baseURL: baseURL, // e.g., http://localhost:8052/api/v1
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Add a request interceptor to include the API key
    this.axiosInstance.interceptors.request.use(
      (config: AxiosRequestConfig) => {
        if (this.apiKey) {
          // Ensure headers object exists
          config.headers = config.headers || {};
          config.headers['X-API-Key'] = this.apiKey;
        }
        return config;
      },
      (error: AxiosError) => {
        return Promise.reject(error);
      }
    );
  }

  private handleApiError(error: AxiosError): never {
    if (error.response) {
      const responseData = error.response.data as JuliaApiResponseError | any;
      // Check if it's our standardized error format
      if (responseData && responseData.error && responseData.error.message) {
        const errDetail = responseData.error;
        throw new ApiClientError(
          errDetail.message,
          errDetail.status_code || error.response.status,
          errDetail.error_code,
          errDetail.details
        );
      } else {
        // Fallback for non-standard errors or network issues
        throw new ApiClientError(
          (error.response.data as any)?.message || error.message,
          error.response.status,
          'UNKNOWN_CLIENT_ERROR',
          error.response.data
        );
      }
    } else if (error.request) {
      // The request was made but no response was received
      throw new ApiClientError('No response received from server', 503, 'NETWORK_ERROR', error.request);
    } else {
      // Something happened in setting up the request that triggered an Error
      throw new ApiClientError(`Request setup error: ${error.message}`, 500, 'REQUEST_SETUP_ERROR');
    }
  }

  public async get<T = any>(path: string, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response: AxiosResponse<T> = await this.axiosInstance.get(path, config);
      return response.data;
    } catch (error) {
      this.handleApiError(error as AxiosError);
    }
  }

  public async post<T = any>(path: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response: AxiosResponse<T> = await this.axiosInstance.post(path, data, config);
      return response.data;
    } catch (error) {
      this.handleApiError(error as AxiosError);
    }
  }

  public async put<T = any>(path: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response: AxiosResponse<T> = await this.axiosInstance.put(path, data, config);
      return response.data;
    } catch (error) {
      this.handleApiError(error as AxiosError);
    }
  }

  public async delete<T = any>(path: string, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response: AxiosResponse<T> = await this.axiosInstance.delete(path, config);
      return response.data;
    } catch (error) {
      this.handleApiError(error as AxiosError);
    }
  }
}

// Example Usage (can be moved to a test file or an example script)
/*
async function main() {
  // Replace with your actual base URL and API key
  const apiClient = new ApiClient('http://localhost:8052/api/v1', 'your-secure-api-key-1');

  try {
    console.log('Listing agents...');
    const agents = await apiClient.get('/agents');
    console.log('Agents:', agents);

    // Example of creating an agent (adjust payload as needed)
    // const newAgentPayload = {
    //   name: "MyTSAgent",
    //   type: "CUSTOM",
    //   abilities: ["ping_ability"],
    // };
    // const newAgent = await apiClient.post('/agents', newAgentPayload);
    // console.log('New Agent:', newAgent);

  } catch (error) {
    if (error instanceof ApiClientError) {
      console.error(`API Error (${error.statusCode}, Code: ${error.errorCode}): ${error.message}`);
      if (error.errorDetails) {
        console.error('Details:', JSON.stringify(error.errorDetails, null, 2));
      }
    } else {
      console.error('Unknown Error:', error);
    }
  }
}

// main();
*/
